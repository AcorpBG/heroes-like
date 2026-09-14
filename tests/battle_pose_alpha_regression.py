#!/usr/bin/env python3
"""Render actual source RGBA over contrasting backgrounds; never alter source art."""
import battle_readability_regression as runner

SCRIPT = r'''extends Node
var failures:=[]
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _ready()->void:call_deferred("run")
func run()->void:
	check(DisplayServer.get_name()!="headless","alpha verification requires rendering")
	get_tree().root.size=Vector2i(1280,720)
	get_tree().root.content_scale_size=Vector2i(1280,720)
	var colors:=[Color("496b90"),Color("d5cba7")]
	for index in range(2):
		var background:=ColorRect.new()
		background.position=Vector2(index*640,0)
		background.size=Vector2(640,720)
		background.color=colors[index]
		add_child(background)
		var filename:="alpha/poses.png" if index==0 else "alternatives/alpha-attempt-2.png"
		var path:="res://art/animation/source/poses/unit_gorefen_ripper/"+filename
		var source:=Image.load_from_file(path)
		check(source!=null and not source.is_empty(),"source missing")
		check(source.get_pixel(0,0).a==0.0,"source corner is not transparent")
		var sprite:=TextureRect.new()
		sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		sprite.texture=ImageTexture.create_from_image(source)
		sprite.position=Vector2(index*640+20,160)
		sprite.size=Vector2(600,400)
		add_child(sprite)
	for i in range(5):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rendered:=get_viewport().get_texture().get_image()
	for index in range(2):
		var pixel:=rendered.get_pixel(index*640+21,161)
		var expected:Color=colors[index]
		check(absf(pixel.r-expected.r)<0.02 and absf(pixel.g-expected.g)<0.02 and absf(pixel.b-expected.b)<0.02,"transparent source RGB leaked into rendered background")
	rendered.save_png(OS.get_environment("BATTLE_READABILITY_OUT").path_join("alpha-contrast.png"))
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"source alpha compositing, not final creature animation acceptance"}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    runner.OUTPUT = runner.ROOT / '.artifacts/battle-unit-animation-size-20260913'
    runner.SCRIPT = SCRIPT
    raise SystemExit(runner.main())
