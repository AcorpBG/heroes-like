// Neutral field economy: shared quotes and transactions for human and AI heroes.
// Stock is per placement, armies belong to the visiting commander, funds to its player.
#include "aurelion_rules/port/field_economy_services.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/generated_reward_rules.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/overworld_rules_heroes.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"
#include <algorithm>
#include <charconv>
#include <set>
#include <string>
#include <vector>

namespace aurelion::rules::port::field_economy_services {
namespace {
using namespace gd;
using state::ContentTable;
namespace key = state::key;
namespace ow = overworld_rules;
namespace identity = player_identity_rules;
constexpr int64_t army_slots = 7;
Atom a(State &s, const char *name) { return s.intern(name); }
Atom text(State &s, DictRef d, Atom k, Atom fallback = key::empty) { return stringify(s,s.get(d,str(k),str(fallback))); }
DictRef sub(State &s, DictRef d, Atom k) { state::Value v;return s.lookup(d,str(k),v)&&is_dict(v)?v.ref:s.new_dict(); }
ArrayRef list(State &s, DictRef d, Atom k) { state::Value v;return s.lookup(d,str(k),v)&&is_array(v)?v.ref:s.new_array(); }
DictRef result(State &s, bool ok, const std::string &message) {
    auto r=s.new_dict();s.set(r,str(key::ok),bool_value(ok));s.set(r,str(key::message),str(s.intern(message)));return r;
}
Atom kind(State &s, DictRef site) {return text(s,site,a(s,"adventure_service"));}
DictRef config(State &s, DictRef site) {return sub(s,site,a(s,"field_economy"));}
DictRef empire(State &s, DictRef session, Atom owner) {
    for(auto v:field_items(s,session_view::overworld(s,session),str(key::enemy_states)))
        if(is_dict(v)&&identity::controller_id(s,v.ref,text(s,v.ref,key::faction_id))==owner)return v.ref;
    return s.new_dict();
}
DictRef funds(State &s, DictRef session, Atom owner) {
    return owner==key::player?sub(s,session_view::overworld(s,session),key::resources):sub(s,empire(s,session,owner),key::treasury);
}
DictRef hero(State &s, DictRef session, Atom owner, DictRef visitor) {
    return owner==key::player?sub(s,session_view::overworld(s,session),key::hero):sub(s,visitor,key::enemy_commander_state);
}
DictRef army(State &s, DictRef session, Atom owner, DictRef visitor) {
    return owner==key::player?sub(s,session_view::overworld(s,session),key::army):sub(s,visitor,key::enemy_army);
}
int64_t week(State &s, DictRef session) {return std::max<int64_t>(0,(ai::session_int(s,session,key::day)-1)/7);}
std::string name(State &s, ContentTable table, Atom id) {return s.text(text(s,content_row(s,table,id),key::name,id));}
DictRef scaled(State &s, DictRef base, int64_t count, int64_t percent) {
    auto out=s.new_dict();
    for(auto k:items(s,dict_value(base))) {
        auto amount=(std::max<int64_t>(0,to_int(s,s.get(base,k,int_value(0))))*count*percent+99)/100;
        if(amount>0)s.set(out,k,int_value(amount));
    }
    return out;
}
bool can_pay(State &s, DictRef purse, DictRef cost) {return town_development_rules::can_pay(s,purse,cost);}
void pay(State &s, DictRef purse, DictRef cost) {
    for(auto k:items(s,dict_value(cost)))s.set(purse,k,int_value(to_int(s,s.get(purse,k,int_value(0)))-to_int(s,s.get(cost,k,int_value(0)))));
}
// A saved week's stock never rerolls when bought, revisited, or loaded. A new
// week rotates the original eligible content pool deterministically, without RNG.
DictRef stock(State &s, DictRef session, DictRef node, DictRef site) {
    auto saved=sub(s,node,a(s,"field_market_stock"));
    if(int_field(s,saved,key::week,-1)==week(s,session))return deep_duplicate_dict(s,saved);
    auto rarities=list(s,config(s,site),a(s,"artifact_rarities"));
    auto excluded=town_development_rules::objective_artifact_ids(s,dict_value(session));
    std::vector<Atom> pool;
    for(auto v:field_items(s,content_file(s,key::artifacts_path),str(key::items)))if(is_dict(v)) {
        auto id=text(s,v.ref,key::id),cls=text(s,v.ref,key::artifact_class);
        if(array_has(s,rarities,str(text(s,v.ref,key::rarity)))&&!bool_field(s,v.ref,key::quest_item,false)
            &&cls!=key::scenario&&cls!=key::relic&&!array_has(s,excluded,str(id)))pool.push_back(id);
    }
    auto seed=s.text(text(s,node,key::placement_id))+":market:"+std::to_string(week(s,session));
    std::sort(pool.begin(),pool.end(),[&](Atom x,Atom y) {
        auto hx=generated_reward_rules::_hash32(s,s.intern(seed+":"+s.text(x)));
        auto hy=generated_reward_rules::_hash32(s,s.intern(seed+":"+s.text(y)));
        return hx==hy?s.text(x)<s.text(y):hx<hy;
    });
    auto out=s.new_dict(),ids=s.new_array();
    auto count=std::clamp<int64_t>(int_field(s,config(s,site),a(s,"stock_size"),5),1,12);
    for(int64_t i=0;i<std::min<int64_t>(count,pool.size());++i)s.append(ids,str(pool[i]));
    s.set(out,str(key::week),int_value(week(s,session)));s.set(out,str(a(s,"artifact_ids")),array_value(ids));
    s.set(out,str(key::sold_ids),array_value(s.new_array()));return out;
}
int64_t market_price(State &s, DictRef site, Atom artifact) {
    return (town_development_rules::price(s,content_row(s,ContentTable::Artifact,artifact))
        *std::max<int64_t>(1,int_field(s,config(s,site),a(s,"price_percent"),100))+99)/100;
}
// Quotes carry the current stack identity/count, or the current market week.
// Submission rebuilds this list, then validates quantity and current treasury.
ArrayRef quotes(State &s, DictRef session, DictRef node, DictRef site, Atom owner, DictRef visitor) {
    auto out=s.new_array(),purse=funds(s,session,owner),h=hero(s,session,owner,visitor);
    auto service=kind(s,site),cfg=config(s,site);
    if(service==a(s,"black_market")) {
        auto inventory=stock(s,session,node,site);auto sold=list(s,inventory,key::sold_ids);
        auto excluded=town_development_rules::objective_artifact_ids(s,dict_value(session));
        for(auto v:field_items(s,inventory,str(a(s,"artifact_ids")))) {
            auto id=stringify(s,v);auto item=content_row(s,ContentTable::Artifact,id);
            auto cls=text(s,item,key::artifact_class);
            if(is_empty(s,item)||array_has(s,sold,str(id))||array_has(s,excluded,str(id))
                ||bool_field(s,item,key::quest_item,false)||cls==key::scenario||cls==key::relic)continue;
            auto q=s.new_dict();auto cost=s.new_dict();s.set(cost,str(key::gold),int_value(market_price(s,site,id)));
            s.set(q,str(key::id),str(s.intern("buy:"+std::to_string(week(s,session))+":"+s.text(id))));
            s.set(q,str(key::artifact_id),str(id));s.set(q,str(key::cost),dict_value(cost));
            s.set(q,str(key::label),str(s.intern("Buy "+name(s,ContentTable::Artifact,id)+" · "+std::to_string(market_price(s,site,id))+" gold")));
            s.set(q,str(key::summary),str(artifact_rules::artifact_effect_summary(s,id)));
            s.set(q,str(key::disabled),bool_value(!can_pay(s,purse,cost)||artifact_rules::has_artifact(s,h,id)));
            s.append(out,dict_value(q));
        }
        return out;
    }
    auto stacks=list(s,army(s,session,owner,visitor),key::stacks);
    int64_t total=0;for(auto v:items(s,array_value(stacks)))if(is_dict(v))total+=std::max<int64_t>(0,int_field(s,v.ref,key::count,0));
    for(int64_t i=0;i<s.array_size(stacks);++i) {
        auto v=s.at(stacks,i);if(!is_dict(v))continue;
        auto id=text(s,v.ref,key::unit_id),unit=content_row(s,ContentTable::Unit,id);
        auto count=int_field(s,v.ref,key::count,0);if(count<=0||is_empty(s,unit))continue;
        auto q=s.new_dict();auto limit=count,min=INT64_C(1);
        std::string label;
        if(service==a(s,"hill_fort")) {
            auto target=text(s,unit,key::upgrade_to);if(target==key::empty||is_empty(s,content_row(s,ContentTable::Unit,target)))continue;
            auto discounts=list(s,cfg,a(s,"cost_percent_by_tier"));auto tier=int_field(s,unit,key::tier,1);
            auto percent=tier>0&&tier<=s.array_size(discounts)?to_int(s,s.at(discounts,tier-1)):100;
            percent=std::clamp<int64_t>(percent,0,100);
            auto cost=town_development_rules::upgrade_cost(s,id,target,1);
            bool target_present=false;for(auto x:items(s,array_value(stacks)))if(is_dict(x)&&text(s,x.ref,key::unit_id)==target)target_present=true;
            if(!target_present&&s.array_size(stacks)>=army_slots)min=count;
            s.set(q,str(a(s,"target_unit_id")),str(target));s.set(q,str(a(s,"quantity_cost")),dict_value(cost));
            s.set(q,str(a(s,"cost_percent")),int_value(percent));
            s.set(q,str(key::label),str(s.intern(name(s,ContentTable::Unit,id)+" → "+name(s,ContentTable::Unit,target))));
            s.set(q,str(key::summary),str(s.intern("Tier "+std::to_string(tier)+" · "+std::to_string(percent)+"% of the normal upgrade cost"+(min>1?" · Whole stack only: no free army slot.":"."))));
        } else {
            limit=std::min(count,total-1);if(limit<=0)continue;
            auto each=int_field(s,sub(s,unit,key::cost),key::gold,0)*int_field(s,cfg,a(s,"sale_percent"),50)/100;
            if(each<=0)continue;
            auto reward=s.new_dict();s.set(reward,str(key::gold),int_value(each));
            s.set(q,str(a(s,"quantity_reward")),dict_value(reward));
            s.set(q,str(key::label),str(s.intern("Sell "+name(s,ContentTable::Unit,id))));
            s.set(q,str(key::summary),str(s.intern(std::to_string(each)+" gold per creature · Sale is permanent.")));
        }
        s.set(q,str(key::id),str(s.intern((service==a(s,"hill_fort")?"upgrade:":"sell:")+std::to_string(i)+":"+s.text(id)+":"+std::to_string(count))));
        s.set(q,str(key::unit_id),str(id));s.set(q,str(key::index),int_value(i));
        s.set(q,str(a(s,"quantity_min")),int_value(min));s.set(q,str(a(s,"quantity_max")),int_value(limit));
        s.set(q,str(a(s,"quantity_default")),int_value(service==a(s,"hill_fort")?limit:min));
        s.append(out,dict_value(q));
    }
    return out;
}
DictRef cost_for(State &s, DictRef q, int64_t quantity) {
    return s.has(q,str(a(s,"quantity_cost")))?scaled(s,sub(s,q,a(s,"quantity_cost")),quantity,int_field(s,q,a(s,"cost_percent"),100)):sub(s,q,key::cost);
}
DictRef execute(State &s, DictRef session, DictRef node, DictRef site, Atom owner, DictRef visitor, Atom action) {
    auto options=quotes(s,session,node,site,owner,visitor);DictRef chosen=0;int64_t quantity=1;
    const std::string command=s.text(action);
    for(auto v:items(s,array_value(options)))if(is_dict(v)) {
        auto id=s.text(text(s,v.ref,key::id));
        if(s.has(v.ref,str(a(s,"quantity_max")))) {
            auto prefix=id+":";if(command.rfind(prefix,0)!=0)continue;
            auto tail=command.substr(prefix.size());auto parse=std::from_chars(tail.data(),tail.data()+tail.size(),quantity);
            if(parse.ec!=std::errc()||parse.ptr!=tail.data()+tail.size()||quantity<int_field(s,v.ref,a(s,"quantity_min"),1)||quantity>int_field(s,v.ref,a(s,"quantity_max"),0))continue;
        } else if(command!=id)continue;
        if(!bool_field(s,v.ref,key::disabled,false))chosen=v.ref;
        break;
    }
    if(!chosen)return result(s,false,"This offer changed or is unavailable. Revisit the service to refresh it.");
    auto purse=funds(s,session,owner),cost=cost_for(s,chosen,quantity);
    if(!can_pay(s,purse,cost))return result(s,false,"You cannot afford that upgrade or purchase.");
    auto h=hero(s,session,owner,visitor);std::string message;
    if(kind(s,site)==a(s,"black_market")) {
        auto id=text(s,chosen,key::artifact_id);
        auto claimed=artifact_rules::claim_artifact(s,h,id,key::Purchased,false);
        if(!bool_field(s,claimed,key::ok,false))return claimed;
        h=sub(s,claimed,key::hero);
        if(owner!=key::player)h=sub(s,enemy_town_services::best_equipment(s,h,id),key::hero);
        auto inventory=stock(s,session,node,site),sold=list(s,inventory,key::sold_ids);
        s.append(sold,str(id));s.set(inventory,str(key::sold_ids),array_value(sold));s.set(node,str(a(s,"field_market_stock")),dict_value(inventory));
        message="Bought "+name(s,ContentTable::Artifact,id)+" for "+std::to_string(market_price(s,site,id))+" gold.";
    } else {
        auto old=army(s,session,owner,visitor),stacks=deep_duplicate_array(s,list(s,old,key::stacks));
        auto index=int_field(s,chosen,key::index,-1);auto source=as_dict(s.at(stacks,index));
        auto count=int_field(s,source,key::count,0);auto id=text(s,chosen,key::unit_id);
        const bool upgrade=kind(s,site)==a(s,"hill_fort");
        if(upgrade) {
            auto target=text(s,chosen,a(s,"target_unit_id"));DictRef destination=0;
            for(auto v:items(s,array_value(stacks)))if(is_dict(v)&&text(s,v.ref,key::unit_id)==target){destination=v.ref;break;}
            if(destination) {
                s.set(destination,str(key::count),int_value(int_field(s,destination,key::count,0)+quantity));
                s.set(source,str(key::count),int_value(count-quantity));
            } else if(quantity==count)s.set(source,str(key::unit_id),str(target));
            else {
                auto addition=s.new_dict();s.set(addition,str(key::unit_id),str(target));s.set(addition,str(key::count),int_value(quantity));
                std::set<int64_t> used;
                // Unslotted stacks are assigned by their original array order.
                for(int64_t i=0;i<s.array_size(stacks);++i)used.insert(int_field(s,as_dict(s.at(stacks,i)),key::slot_index,i));
                for(int64_t slot=0;slot<army_slots;++slot)if(!used.count(slot)){s.set(addition,str(key::slot_index),int_value(slot));break;}
                s.append(stacks,dict_value(addition));s.set(source,str(key::count),int_value(count-quantity));
            }
            message="Upgraded "+std::to_string(quantity)+" "+name(s,ContentTable::Unit,id)+" to "+name(s,ContentTable::Unit,target)+".";
        } else {
            auto reward=scaled(s,sub(s,chosen,a(s,"quantity_reward")),quantity,100);
            s.set(source,str(key::count),int_value(count-quantity));
            s.set(purse,str(key::gold),int_value(int_field(s,purse,key::gold,0)+int_field(s,reward,key::gold,0)));
            message="Sold "+std::to_string(quantity)+" "+name(s,ContentTable::Unit,id)+" for "+std::to_string(int_field(s,reward,key::gold,0))+" gold.";
        }
        auto kept=s.new_array();for(auto v:items(s,array_value(stacks)))if(is_dict(v)&&int_field(s,v.ref,key::count,0)>0)s.append(kept,v);
        auto changed=deep_duplicate_dict(s,old);s.set(changed,str(key::stacks),array_value(kept));s.set(h,str(key::army),dict_value(changed));
        if(owner==key::player)s.set(session_view::overworld(s,session),str(key::army),dict_value(changed));
        else s.set(visitor,str(key::enemy_army),dict_value(changed));
    }
    pay(s,purse,cost);
    if(owner==key::player) {
        s.set(session_view::overworld(s,session),str(key::hero),dict_value(h));hero_command_rules::commit_active_hero(s,session);
    } else s.set(visitor,str(key::enemy_commander_state),dict_value(h));
    return result(s,true,message);
}
Atom ai_action(State &s, DictRef session, DictRef node, DictRef site, Atom owner, DictRef visitor) {
    auto options=quotes(s,session,node,site,owner,visitor),purse=deep_duplicate_dict(s,funds(s,session,owner));
    auto cfg=config(s,site),h=hero(s,session,owner,visitor),stacks=list(s,army(s,session,owner,visitor),key::stacks);
    auto service=kind(s,site);
    auto reserve=int_field(s,cfg,a(s,"ai_gold_reserve"),1000);
    s.set(purse,str(key::gold),int_value(std::max<int64_t>(0,int_field(s,purse,key::gold,0)-reserve)));
    double best=0;Atom action=key::empty;
    for(auto v:items(s,array_value(options)))if(is_dict(v)&&!bool_field(s,v.ref,key::disabled,false)) {
        auto q=v.ref,id=text(s,q,key::id);double value=0;int64_t count=1;
        if(service==a(s,"black_market")) {
            auto aid=text(s,q,key::artifact_id);if(!can_pay(s,purse,sub(s,q,key::cost)))continue;
            auto preview=artifact_rules::claim_artifact(s,h,aid,key::purchase_preview,false);if(!bool_field(s,preview,key::ok,false))continue;
            auto gain=to_float(s.get(enemy_town_services::best_equipment(s,sub(s,preview,key::hero),aid),str(key::gain),float_value(0)));
            value=gain/std::max<int64_t>(1,market_price(s,site,aid));
        } else if(service==a(s,"hill_fort")) {
            auto lo=int_field(s,q,a(s,"quantity_min"),1),hi=int_field(s,q,a(s,"quantity_max"),0);
            count=0;while(lo<=hi){auto mid=lo+(hi-lo)/2;if(can_pay(s,purse,cost_for(s,q,mid))){count=mid;lo=mid+1;}else hi=mid-1;}
            if(count==0)continue;
            value=static_cast<double>(count)*int_field(s,content_row(s,ContentTable::Unit,text(s,q,key::unit_id)),key::tier,1);
        } else {
            if(int_field(s,funds(s,session,owner),key::gold,0)>=int_field(s,cfg,a(s,"ai_gold_target"),1500)||s.array_size(stacks)<2)continue;
            auto uid=text(s,q,key::unit_id),unit=content_row(s,ContentTable::Unit,uid);
            bool obsolete=false;for(auto x:items(s,array_value(stacks)))if(is_dict(x)&&text(s,x.ref,key::unit_id)==text(s,unit,key::upgrade_to))obsolete=true;
            auto faction=text(s,unit,key::faction_id);
            bool foreign=faction!=key::empty&&faction!=identity::faction_id(s,session,owner);
            auto single=s.new_array();s.append(single,s.at(stacks,int_field(s,q,key::index,0)));
            auto power=ai_hero_rules::army_power(s,array_value(single),dict_value(h));
            auto total=ai_hero_rules::army_power(s,array_value(stacks),dict_value(h));
            auto share=to_float(s.get(cfg,str(a(s,"ai_sale_power_share")),float_value(0.1)));
            if((!obsolete&&!foreign)||power>total*share)continue;
            count=int_field(s,q,a(s,"quantity_max"),0);value=static_cast<double>(count)*int_field(s,sub(s,q,a(s,"quantity_reward")),key::gold,0);
        }
        if(value>best) {best=value;action=s.has(q,str(a(s,"quantity_max")))?s.intern(s.text(id)+":"+std::to_string(count)):id;}
    }
    return action;
}
DictRef prompt(State &s, DictRef session, DictRef node, DictRef site) {
    auto panel=s.new_dict();s.set(panel,str(a(s,"field_service")),bool_value(true));s.set(panel,str(a(s,"economy_service")),bool_value(true));
    s.set(panel,str(key::title),str(text(s,site,key::name)));s.set(panel,str(key::asset_id),str(text(s,site,key::overworld_sprite_asset_id)));
    s.set(panel,str(key::context),dict_value(ow::_resource_reward_choice_context(s,session,node)));
    s.set(panel,str(a(s,"available_resources")),dict_value(deep_duplicate_dict(s,funds(s,session,key::player))));
    auto choices=quotes(s,session,node,site,key::player,0);auto instruction=s.text(text(s,site,key::public_text));
    if(kind(s,site)==a(s,"black_market"))instruction+="\nWeek "+std::to_string(week(s,session)+1)+" · Stock is shared by all visitors.";
    if(s.array_size(choices)==0)instruction+="\nNo eligible troops or unsold offers are available.";
    s.set(panel,str(key::instruction),str(s.intern(instruction)));s.set(panel,str(key::choices),array_value(choices));return panel;
}
} // namespace

bool handles(State &s, DictRef site) {auto k=kind(s,site);return k==a(s,"hill_fort")||k==a(s,"black_market")||k==a(s,"freelancer_guild");}
bool available(State &s, DictRef session, DictRef node, DictRef site, Atom owner, DictRef visitor) {
    if(visitor)return ai_action(s,session,node,site,owner,visitor)!=key::empty;
    if(owner==key::player)return s.array_size(quotes(s,session,node,site,owner,0))>0;
    for(auto v:field_items(s,session_view::overworld(s,session),str(key::encounters)))if(is_dict(v)
        &&identity::raid_controller_id(s,v.ref)==owner&&!ow::is_encounter_resolved(s,session,v.ref)
        &&ai_action(s,session,node,site,owner,v.ref)!=key::empty)return true;
    return false;
}
DictRef visit(State &s, DictRef session, DictRef node_result, DictRef site, bool refresh, Atom choice) {
    auto nodes=list(s,session_view::overworld(s,session),key::resource_nodes);auto index=int_field(s,node_result,key::index,-1);
    if(index<0||index>=s.array_size(nodes))return result(s,false,"No service is here.");
    auto node=as_dict(s.at(nodes,index));
    if(choice==key::empty){auto r=result(s,true,s.text(text(s,site,key::name)));s.set(r,str(key::route),str(key::reward_choice));s.set(r,str(key::reward_choice),dict_value(prompt(s,session,node,site)));return r;}
    auto r=execute(s,session,node,site,key::player,0,choice);if(!bool_field(s,r,key::ok,false))return r;
    auto final=ow::_finalize_action_result(s,session,true,text(s,r,key::message),refresh,false,s.new_dict());
    s.set(final,str(key::reward_choice),dict_value(prompt(s,session,node,site)));return final;
}
DictRef visit_ai(State &s, DictRef session, DictRef raid, DictRef state_, Atom owner, DictRef node_result, DictRef site) {
    auto node=sub(s,node_result,key::node);auto action=ai_action(s,session,node,site,owner,raid);
    auto r=action==key::empty?result(s,false,"No useful field trade is available."):execute(s,session,node,site,owner,raid,action);
    auto out=s.new_dict();s.set(out,str(key::encounter),dict_value(raid));s.set(out,str(key::state),dict_value(state_));
    s.set(out,str(key::event_message),str(text(s,r,key::message)));s.set(out,str(key::ai_events),array_value(s.new_array()));return out;
}
} // namespace aurelion::rules::port::field_economy_services
