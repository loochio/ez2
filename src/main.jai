/* main.jai - clip prototype

10 April 2026 - clip browser, custom cml (clip markup language)
*/

main_cfg := EngineConfig.{
	window_title = "ez sdl",
	window_x = 450,
	window_y = 100,
	window_width = 640,
	window_height = 1080,
	aspect = 640. / 480.,
	bg_color = Vector4.{0.02, 0.188, 0.02, 1},
	world_width = 640,
	world_height = 480,
	font = "OpenSans-BoldItalic.ttf",
	default_texture = "default.png",
	vsync = false,
	fps_target = 144,
	fps_unlimitted = false,
};

main :: () {
	log("% main start\n", main_cfg.window_title);

	main_cfg.startup_plugin = default_plugin; // default_plugin defined in build.jai
	//array_add(*main_cfg.plugins, browser_plugin);
	array_add(*main_cfg.plugins, game_plugin);
	
	engine_run(main_cfg);
	log("[%] main() exitting cleanly.\n", main_cfg.window_title);
}

#load "engine.jai";
//#load "node.jai";
//#load "curl.jai";

#load "game.jai";
