// Field recruitment, prisoner rescue and kingdom intelligence. Human and AI
// callers share availability, transactions and persistent placement state.
#include "aurelion_rules/port/adventure_services.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules_human.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"
#include "aurelion_rules/port/overworld_rules_heroes.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"
#include <algorithm>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace aurelion::rules::port::enemy_adventure_rules {
gd::DictRef build_roster_commander_state(state::State &, gd::Atom, gd::Atom, gd::DictRef, const state::Value &);
}

namespace aurelion::rules::port::adventure_services {
namespace {
using namespace gd;
using state::ContentTable;
using state::Value;
namespace key = state::key;
namespace ow = overworld_rules;
namespace hc = hero_command_rules;
namespace id = player_identity_rules;
Atom atom(State &s, const char *text) { return s.intern(text); }
Atom text(State &s, DictRef d, Atom k, Atom fallback = key::empty) {
    return gd::stringify(s, s.get(d, str(k), str(fallback)));
}
DictRef sub(State &s, DictRef d, Atom k) {
    Value v; return s.lookup(d, str(k), v) && is_dict(v) ? v.ref : s.new_dict();
}
ArrayRef list(State &s, DictRef d, Atom k) {
    Value v; return s.lookup(d, str(k), v) && is_array(v) ? v.ref : s.new_array();
}
DictRef outcome(State &s, bool ok, const std::string &message) {
    auto r=s.new_dict(); s.set(r,str(key::ok),bool_value(ok));
    s.set(r,str(key::message),str(s.intern(message))); return r;
}
Atom kind(State &s, DictRef site) { return text(s,site,atom(s,"adventure_service")); }
DictRef empire_for(State &s, DictRef session, Atom owner) {
    for (auto v:field_items(s,session_view::overworld(s,session),str(key::enemy_states)))
        if (is_dict(v) && id::controller_id(s,v.ref,text(s,v.ref,key::faction_id))==owner) return v.ref;
    return s.new_dict();
}
DictRef treasury(State &s, DictRef session, Atom owner) {
    return owner==key::player ? sub(s,session_view::overworld(s,session),key::resources)
                             : sub(s,empire_for(s,session,owner),key::treasury);
}
bool paid(State &s, DictRef pool, DictRef cost) {
    for (auto k:items(s,dict_value(cost)))
        if (to_int(s,s.get(pool,k,int_value(0)))<to_int(s,s.get(cost,k,int_value(0)))) return false;
    return true;
}
std::set<std::string> taken(State &s, DictRef session) {
    std::set<std::string> result;
    auto world=session_view::overworld(s,session);
    for (auto h:field_items(s,world,str(key::player_heroes)))
        if(is_dict(h)) result.insert(s.text(text(s,h.ref,key::id)));
    for (auto e:field_items(s,world,str(key::encounters))) {
        if(!is_dict(e) || ow::is_encounter_resolved(s,session,e.ref)) continue;
        auto c=sub(s,e.ref,key::enemy_commander_state);
        auto hero=text(s,c,key::roster_hero_id,text(s,c,key::id));
        if(hero!=key::empty) result.insert(s.text(hero));
    }
    for(auto e:field_items(s,world,str(key::enemy_states))) if(is_dict(e))
        for(auto r:field_items(s,e.ref,str(key::commander_roster))) if(is_dict(r)
            && text(s,r.ref,key::status)==key::recovering
            && int_field(s,r.ref,key::recovery_day,0)>ai::session_int(s,session,key::day))
            result.insert(s.text(text(s,r.ref,key::roster_hero_id)));
    return result;
}
ArrayRef candidates(State &s, DictRef session, DictRef node, DictRef site, Atom owner) {
    auto out=s.new_array();
    const bool prison=kind(s,site)==atom(s,"prison");
    if(prison && bool_field(s,node,atom(s,"prison_released"),false)) return out;
    int64_t count=owner==key::player ? hc::player_hero_count(s,session) : ai_hero_rules::active_hero_count(s,session,owner);
    // The same four-command limit as town recruitment, for paid and free hires.
    if(count>=4) return out;
    ArrayRef pool;
    if(prison) {
        auto faction=gd::content_row(s,ContentTable::Faction,id::faction_id(s,session,owner));
        pool=list(s,faction,key::hero_ids);
        // Legacy human alias is normalized through the scenario's faction.
        if(owner==key::player && s.array_size(pool)==0) pool=hc::_tavern_candidate_ids(s,session);
    } else pool=owner==key::player ? hc::tavern_offer_ids(s,session)
                    : ai_hero_rules::ai_tavern_offer_ids(s,session,empire_for(s,session,owner),owner);
    auto used=taken(s,session);
    std::vector<Atom> eligible;
    for(auto v:items(s,array_value(pool))) {
        auto hero=gd::stringify(s,v);
        auto row=gd::content_row(s,ContentTable::Hero,hero);
        if(hero!=key::empty && !used.count(s.text(hero)) && !is_empty(s,row)
            && text(s,row,key::roster_state)!=key::scaffold) eligible.push_back(hero);
    }
    if(prison) {
        // Placement-fixed ordering, filtered against the current unique roster.
        const auto seed=s.text(text(s,node,key::placement_id))+":"+s.text(owner);
        std::sort(eligible.begin(),eligible.end(),[&](Atom a,Atom b) {
            auto ha=gd::hash(s,str(s.intern(seed+":"+s.text(a))));
            auto hb=gd::hash(s,str(s.intern(seed+":"+s.text(b))));
            return ha==hb ? s.text(a)<s.text(b) : ha<hb;
        });
        if(!eligible.empty()) s.append(out,str(eligible.front()));
    } else for(auto hero:eligible) s.append(out,str(hero));
    return out;
}
DictRef spawn_position(State &s, DictRef session, DictRef node) {
    auto size=ow::derive_map_size(s,session);
    auto x=int_field(s,node,key::x,0), y=int_field(s,node,key::y,0);
    auto level=overworld_level_rules::level_of(s,dict_value(node));
    constexpr int offsets[][2]={{0,1},{1,0},{-1,0},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}};
    for(auto &d:offsets) {
        auto tx=x+d[0],ty=y+d[1];
        if(tx<0||ty<0||tx>=size.x||ty>=size.y||ow::tile_is_blocked(s,session,tx,ty,level)) continue;
        bool occupied=false;
        for(auto h:field_items(s,session_view::overworld(s,session),str(key::player_heroes))) if(is_dict(h)) {
            auto p=sub(s,h.ref,key::position);
            if(overworld_level_rules::level_of(s,dict_value(p))==level && int_field(s,p,key::x,-1)==tx && int_field(s,p,key::y,-1)==ty) occupied=true;
        }
        if(occupied || ow::tile_has_route_interaction(s,session,tx,ty,level)) continue;
        if(!is_empty(s,ow::guard_engagement_encounter_at_tile(s,session,tx,ty,level))) continue;
        if(ow::tile_step_cuts_blocked_corner(s,session,ow::Vector2i::of(x,y),ow::Vector2i::of(tx,ty),level)) continue;
        auto result=s.new_dict(); s.set(result,str(key::x),int_value(tx));s.set(result,str(key::y),int_value(ty));s.set(result,str(key::level),int_value(level));
        return result;
    }
    return s.new_dict();
}
void consume_offer(State &s, DictRef session, Atom owner, Atom hero, ArrayRef offered) {
    auto holder=owner==key::player?session_view::overworld(s,session):empire_for(s,session,owner);
    auto field=owner==key::player?key::tavern_rotation:key::ai_tavern;
    auto rotation=gd::deep_duplicate_dict(s,sub(s,holder,field));
    auto ids=gd::duplicate_array(s,offered);
    ai::array_erase(s,ids,str(hero));s.set(rotation,str(key::hero_ids),array_value(ids));
    s.set(rotation,str(key::week),int_value(hc::tavern_week(s,session)));
    s.set(holder,str(field),dict_value(rotation));
}
DictRef recruit(State &s, DictRef session, DictRef node, DictRef site, Atom owner, Atom hero) {
    auto pool=candidates(s,session,node,site,owner);
    if(!gd::array_has(s,pool,str(hero))) return outcome(s,false,"That commander is no longer available, or your four-command limit is reached.");
    auto weekly=gd::duplicate_array(s,owner==key::player?hc::tavern_offer_ids(s,session):ai_hero_rules::ai_tavern_offer_ids(s,session,empire_for(s,session,owner),owner));
    auto position=spawn_position(s,session,node);
    if(is_empty(s,position)) return outcome(s,false,"Clear a safe adjacent land tile before recruiting a commander.");
    bool prison=kind(s,site)==atom(s,"prison");
    auto row=gd::content_row(s,ContentTable::Hero,hero);
    auto price=prison?s.new_dict():hc::hero_recruit_cost(s,row);
    auto funds=treasury(s,session,owner);
    if(!paid(s,funds,price)) return outcome(s,false,"You cannot afford this commander's recruitment cost.");
    auto offer=hc::tavern_offer(s,session,hero,prison?0:-1);
    auto level=prison?1:int_field(s,offer,key::level,1);
    auto growth=hc::fixed_match_roll_seed(s,session);
    if(growth!=key::empty) growth=s.intern(s.text(growth)+":growth:"+s.text(hero));
    auto hired=hc::build_recruited_hero(s,row,position,dict_value(session),level,dict_value(sub(s,offer,key::army)),key::empty,growth);
    if(is_empty(s,hired)) return outcome(s,false,"This commander could not join the roster.");
    auto world=session_view::overworld(s,session);
    if(owner==key::player) {
        auto heroes=list(s,world,key::player_heroes);s.append(heroes,dict_value(hired));
        s.set(world,str(key::player_heroes),array_value(heroes));
    } else {
        auto empire=empire_for(s,session,owner);
        auto counter=int_field(s,empire,key::ai_hero_counter,0)+1;
        auto placement=s.intern(s.text(owner)+"_hero_"+std::to_string(counter));
        auto commander_seed=gd::deep_duplicate_dict(s,hired);
        gd::merge(s,commander_seed,id::identity_fields(s,session,owner),true);
        auto commander=enemy_adventure_rules::build_roster_commander_state(s,hero,owner,commander_seed,dict_value(s.new_dict()));
        s.set(commander,str(key::base_movement),int_value(int_field(s,hired,key::base_movement,int_field(s,row,key::base_movement,10))));
        auto entry=s.new_dict();
        s.set(entry,str(key::placement_id),str(placement));s.set(entry,str(key::encounter_id),str(key::encounter_mire_raid));
        for(auto k:{key::x,key::y,key::level}) s.set(entry,str(k),s.get(position,str(k),int_value(0)));
        s.set(entry,str(key::combat_seed),int_value(gd::hash(s,str(placement))));
        s.set(entry,str(key::spawned_by_faction_id),str(id::faction_id(s,session,owner)));
        s.set(entry,str(key::spawned_by_player_id),str(text(s,id::player(s,session,owner),key::player_id)));
        s.set(entry,str(key::enemy_army),dict_value(gd::deep_duplicate_dict(s,sub(s,hired,key::army))));
        s.set(entry,str(key::enemy_commander_state),dict_value(commander));
        s.set(entry,str(key::days_active),int_value(0));
        auto ai_data=s.new_dict();s.set(ai_data,str(key::hero_id),str(hero));s.set(ai_data,str(key::hired_day),int_value(ai::session_int(s,session,key::day)));
        s.set(ai_data,str(key::home_town_id),str(key::empty));s.set(ai_data,str(key::goal),dict_value(s.new_dict()));
        auto movement=s.new_dict();auto maximum=hc::movement_max_for_hero(s,hired,dict_value(session));
        s.set(movement,str(key::current),int_value(maximum));s.set(movement,str(key::max),int_value(maximum));
        s.set(ai_data,str(key::movement),dict_value(movement));s.set(entry,str(key::ai_hero),dict_value(ai_data));
        auto encounters=list(s,world,key::encounters);s.append(encounters,dict_value(entry));s.set(world,str(key::encounters),array_value(encounters));
        s.set(empire,str(key::ai_hero_counter),int_value(counter));
    }
    for(auto k:items(s,dict_value(price))) s.set(funds,k,int_value(to_int(s,s.get(funds,k,int_value(0)))-to_int(s,s.get(price,k,int_value(0)))));
    consume_offer(s,session,owner,hero,weekly);
    if(prison) {s.set(node,str(atom(s,"prison_released")),bool_value(true));s.set(node,str(atom(s,"released_hero_id")),str(hero));}
    ow::invalidate_spatial_lookup(s,session);
    auto r=outcome(s,true,s.text(text(s,hired,key::name,hero))+(prison?" is rescued and joins your command.":" joins your command beside the lodge."));
    s.set(r,str(key::hero_id),str(hero));s.set(r,str(key::position),dict_value(position));return r;
}

struct Kingdom { Atom owner=key::empty; std::string name; int64_t towns=0,mines=0,heroes=0,creatures=0,gold=0; double strength=0; };
std::vector<Kingdom> kingdoms(State &s,DictRef session) {
    auto world=session_view::overworld(s,session);
    std::map<std::string,Kingdom> rows;
    auto row=[&](Atom owner)->Kingdom& {
        auto &r=rows[s.text(owner)];r.owner=owner;
        if(r.name.empty()) {
            auto player=id::player(s,session,owner); auto faction=id::faction_id(s,session,owner);
            if(owner==key::player && faction==key::player) faction=text(s,gd::content_row(s,ContentTable::Hero,text(s,sub(s,world,key::hero),key::id)),key::faction_id);
            r.name=s.text(text(s,gd::content_row(s,ContentTable::Faction,faction),key::name,faction));
            if(!is_empty(s,player)) {
                auto seat=s.text(owner);
                if(seat.rfind("player_",0)==0) seat="Player "+seat.substr(7);
                r.name+=" ["+seat+"]";
            }
        }
        return r;
    };
    auto add_army=[&](Kingdom &r,DictRef army,DictRef commander) {
        auto stacks=list(s,army,key::stacks);
        for(auto v:items(s,array_value(stacks))) if(is_dict(v)) r.creatures+=std::max<int64_t>(0,int_field(s,v.ref,key::count,0));
        r.strength+=ai_hero_rules::army_power(s,array_value(stacks),dict_value(commander));
    };
    if(id::has_human_seat(s,session) || s.array_size(list(s,world,key::player_heroes))>0)
        row(key::player).gold=int_field(s,sub(s,world,key::resources),key::gold,0);
    for(auto e:field_items(s,world,str(key::enemy_states))) if(is_dict(e)) {
        auto owner=id::controller_id(s,e.ref,text(s,e.ref,key::faction_id));
        row(owner).gold=int_field(s,sub(s,e.ref,key::treasury),key::gold,0);
    }
    for(auto t:field_items(s,world,str(key::towns))) if(is_dict(t)) {
        auto owner=text(s,t.ref,key::owner)==key::player?key::player:id::town_controller_id(s,t.ref);
        if(text(s,t.ref,key::owner)==key::neutral||owner==key::empty) continue;
        auto &r=row(owner);++r.towns;
        auto army=s.new_dict();s.set(army,str(key::stacks),array_value(list(s,t.ref,key::garrison)));add_army(r,army,s.new_dict());
    }
    for(auto h:field_items(s,world,str(key::player_heroes))) if(is_dict(h)) {auto &r=row(key::player);++r.heroes;add_army(r,sub(s,h.ref,key::army),h.ref);}
    for(auto e:field_items(s,world,str(key::encounters))) if(is_dict(e)&&!ow::is_encounter_resolved(s,session,e.ref)) {
        auto owner=id::raid_controller_id(s,e.ref);if(owner==key::empty||owner==key::neutral)continue;
        auto &r=row(owner);++r.heroes;add_army(r,sub(s,e.ref,key::enemy_army),sub(s,e.ref,key::enemy_commander_state));
    }
    for(auto n:field_items(s,world,str(key::resource_nodes))) if(is_dict(n)) {
        auto site=gd::content_row(s,ContentTable::ResourceSite,text(s,n.ref,key::site_id));
        auto owner=id::resource_controller_id(s,n.ref);
        if(text(s,site,key::family)==key::mine&&owner!=key::empty&&owner!=key::neutral)++row(owner).mines;
    }
    std::vector<Kingdom> result;for(auto &r:rows)result.push_back(r.second);
    std::sort(result.begin(),result.end(),[](const Kingdom &a,const Kingdom &b){return a.strength==b.strength?a.name<b.name:a.strength>b.strength;});return result;
}
std::string intelligence(State &s,DictRef session,DictRef node,Atom owner) {
    std::string report="Kingdom intelligence — day "+std::to_string(ai::session_int(s,session,key::day))+"\n";
    int rank=0;
    for(auto &r:kingdoms(s,session)) report+="\n"+std::to_string(++rank)+". "+r.name+"\nTowns "+std::to_string(r.towns)+" · Mines "+std::to_string(r.mines)+" · Commanders "+std::to_string(r.heroes)+" · Creatures "+std::to_string(r.creatures)+" · Gold "+std::to_string(r.gold)+"\n";
    report+="\nRanked by current field armies and town garrisons. Town locations are marked on your map. This is a visit-time snapshot.";
    auto visits=sub(s,node,atom(s,"intelligence_visits"));s.set(visits,str(owner),int_value(ai::session_int(s,session,key::day)));s.set(node,str(atom(s,"intelligence_visits")),dict_value(visits));
    auto snapshot=s.new_dict();s.set(snapshot,str(key::day),int_value(ai::session_int(s,session,key::day)));s.set(snapshot,str(key::message),str(s.intern(report)));
    auto snapshots=sub(s,node,atom(s,"intelligence_reports"));s.set(snapshots,str(owner),dict_value(snapshot));s.set(node,str(atom(s,"intelligence_reports")),dict_value(snapshots));
    // Reveal town anchors and doorways, on their own levels. The AI stores the
    // same facts in its normal bit-packed exploration, read by the next plan/day.
    auto world=session_view::overworld(s,session);
    auto empire=owner==key::player?s.new_dict():empire_for(s,session,owner);
    auto positions=s.new_array();
    for(auto t:field_items(s,world,str(key::towns))) if(is_dict(t)&&text(s,t.ref,key::owner)!=key::neutral) {
        auto entrance=overworld_level_rules::town_entrance(s,t.ref);
        for(auto pos:{t.ref,entrance}) {
            if(owner==key::player) ow::_reveal_resource_site_claim_fog(s,session,pos,1);
            else {
                auto location=s.new_dict();
                s.set(location,str(key::x),int_value(int_field(s,pos,key::x,0)));
                s.set(location,str(key::y),int_value(int_field(s,pos,key::y,0)));
                s.set(location,str(key::level),int_value(overworld_level_rules::level_of(s,dict_value(pos))));
                s.append(positions,dict_value(location));
            }
        }
    }
    if(owner!=key::player)s.set(empire,str(atom(s,"intelligence_town_positions")),array_value(positions));
    return report;
}
std::string army_description(State &s, DictRef offer) {
    std::string result="Starting army: ";
    bool first=true;
    for (auto v:field_items(s,sub(s,offer,key::army),str(key::stacks))) if (is_dict(v) && int_field(s,v.ref,key::count,0)>0) {
        if (!first) result+=", ";
        auto unit=text(s,v.ref,key::unit_id);
        result+=std::to_string(int_field(s,v.ref,key::count,0))+" "+s.text(text(s,gd::content_row(s,ContentTable::Unit,unit),key::name,unit));
        first=false;
    }
    return result;
}
DictRef prompt(State &s,DictRef session,DictRef node,DictRef site,ArrayRef choices,const std::string &instruction) {
    auto r=outcome(s,true,s.text(text(s,site,key::name)));s.set(r,str(key::route),str(key::reward_choice));
    auto panel=s.new_dict();s.set(panel,str(atom(s,"field_service")),bool_value(true));s.set(panel,str(atom(s,"intelligence_report")),bool_value(kind(s,site)==atom(s,"intelligence")));s.set(panel,str(key::title),str(text(s,site,key::name)));
    s.set(panel,str(key::asset_id),str(text(s,site,key::overworld_sprite_asset_id)));
    s.set(panel,str(key::context),dict_value(ow::_resource_reward_choice_context(s,session,node)));
    s.set(panel,str(key::instruction),str(s.intern(instruction)));s.set(panel,str(key::choices),array_value(choices));s.set(r,str(key::reward_choice),dict_value(panel));return r;
}
} // namespace

void apply_intelligence(State &s,DictRef context,PackedRef tiles,int64_t level) {
    auto size=s.get(context,str(key::map_size),Value());
    if(!is_vector2i(size))return;
    auto empire=sub(s,context,key::state);
    for(auto p:field_items(s,empire,str(atom(s,"intelligence_town_positions")))) if(is_dict(p)
        && overworld_level_rules::level_of(s,p)==level) {
        auto x=int_field(s,p.ref,key::x,-1),y=int_field(s,p.ref,key::y,-1);
        for(int dy=-1;dy<=1;++dy)for(int dx=-1;dx<=1;++dx) {
            auto tx=x+dx,ty=y+dy;auto i=ty*size.vx()+tx;
            if(tx>=0&&ty>=0&&tx<size.vx()&&ty<size.vy()&&i<gd::packed_size(s,tiles))gd::packed_set(s,tiles,i,1);
        }
    }
}

bool handles(State &s,DictRef site) {auto k=kind(s,site);return k==atom(s,"tavern")||k==atom(s,"prison")||k==atom(s,"intelligence");}
bool available(State &s,DictRef session,DictRef node,DictRef site,Atom owner) {
    if(kind(s,site)==atom(s,"intelligence")) {
        auto visits=sub(s,node,atom(s,"intelligence_visits"));Value day;
        return !s.lookup(visits,str(owner),day)||ai::session_int(s,session,key::day)-to_int(s,day)>=7;
    }
    if(is_empty(s,spawn_position(s,session,node))) return false;
    auto options=candidates(s,session,node,site,owner);
    for(auto v:items(s,array_value(options))) {
        auto price=kind(s,site)==atom(s,"prison")?s.new_dict():hc::hero_recruit_cost(s,gd::content_row(s,ContentTable::Hero,gd::stringify(s,v)));
        if(paid(s,treasury(s,session,owner),price))return true;
    }
    return false;
}
DictRef visit(State &s,DictRef session,DictRef node_result,DictRef site,bool refresh,Atom choice) {
    auto nodes=list(s,session_view::overworld(s,session),key::resource_nodes);auto index=int_field(s,node_result,key::index,-1);
    if(index<0||index>=s.array_size(nodes))return outcome(s,false,"No service is here.");
    auto node=gd::as_dict(s.at(nodes,index));auto service=kind(s,site);
    if(service==atom(s,"intelligence")) {
        if(choice==atom(s,"close_report"))return ow::_finalize_action_result(s,session,true,s.intern("The intelligence report is recorded."),refresh,false,s.new_dict());
        if(choice!=key::empty)return outcome(s,false,"That intelligence action is no longer available.");
        auto report=intelligence(s,session,node,key::player);auto choices=s.new_array();auto c=s.new_dict();s.set(c,str(key::id),str(atom(s,"close_report")));s.set(c,str(key::label),str(atom(s,"Close report")));s.append(choices,dict_value(c));return prompt(s,session,node,site,choices,report);
    }
    auto options=candidates(s,session,node,site,key::player);
    if(choice==key::empty) {
        if(s.array_size(options)==0)return outcome(s,false,service==atom(s,"prison")&&bool_field(s,node,atom(s,"prison_released"),false)?"This stockade is empty; its prisoner has already been freed.":"No commander can join your roster. Check the four-command limit and available heroes.");
        auto choices=s.new_array();for(auto v:items(s,array_value(options))) {
            auto hero=gd::stringify(s,v);auto row=gd::content_row(s,ContentTable::Hero,hero);auto c=s.new_dict();
            bool prison=service==atom(s,"prison");auto price=prison?s.new_dict():hc::hero_recruit_cost(s,row);auto offer=hc::tavern_offer(s,session,hero,prison?0:-1);
            auto label=std::string(prison?"Rescue ":"Hire ")+s.text(text(s,row,key::name,hero))+" · level "+std::to_string(prison?1:int_field(s,offer,key::level,1))+" · "+(prison?"free":s.text(ow::_describe_resource_delta(s,dict_value(price))));
            s.set(c,str(key::id),str(hero));s.set(c,str(key::label),str(s.intern(label)));s.set(c,str(key::summary),str(s.intern(army_description(s,offer))));s.append(choices,dict_value(c));
        }
        return prompt(s,session,node,site,choices,s.text(text(s,site,key::public_text)));
    }
    auto result=recruit(s,session,node,site,key::player,choice);
    if(!bool_field(s,result,key::ok,false))return result;
    auto final=ow::_finalize_action_result(s,session,true,text(s,result,key::message),refresh,false,s.new_dict());
    s.set(final,str(key::hero_id),str(choice));return final;
}
DictRef visit_ai(State &s,DictRef session,DictRef raid,DictRef empire,Atom owner,DictRef node_result,DictRef site) {
    auto node=sub(s,node_result,key::node);auto result=outcome(s,false,"No service is available.");
    if(available(s,session,node,site,owner)) {
        if(kind(s,site)==atom(s,"intelligence")) {intelligence(s,session,node,owner);result=outcome(s,true,"The commander gathers kingdom intelligence.");}
        else for(auto hero:items(s,array_value(candidates(s,session,node,site,owner)))) {
            result=recruit(s,session,node,site,owner,gd::stringify(s,hero));if(bool_field(s,result,key::ok,false))break;
        }
    }
    auto out=s.new_dict();s.set(out,str(key::encounter),dict_value(raid));s.set(out,str(key::state),dict_value(empire));
    s.set(out,str(key::event_message),str(text(s,result,key::message)));s.set(out,str(key::ai_events),array_value(s.new_array()));return out;
}
} // namespace aurelion::rules::port::adventure_services
