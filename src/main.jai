/* main.jai - clip prototype

10 April 2026 - clip browser, custom cml (clip markup language)
*/

main_cfg := EngineConfig.{
	window_title = "ez sdl",
	window_x = 300,
	window_y = 100,
	window_width = 640,
	window_height = 480,
	aspect = 640. / 480.,
	bg = Vector4.{0.404, 0.059, 0.412, 1},
	world_width = 640,
	world_height = 480,
	font = "OpenSans-BoldItalic.ttf",
	default_texture = "default.png",
	vsync = false,
	fps_target = 144,
	fps_unlimitted = false,
	
	startup_plugin = STARTUP_PLUGIN, // defined in build.jai
	plugins = EnginePlugin.[
		PLUGIN_GAME
	],
};

main :: () {
	engine_run(main_cfg);
}

#load "engine.jai";
//#load "node.jai";
//#load "curl.jai";

#load "game.jai";
