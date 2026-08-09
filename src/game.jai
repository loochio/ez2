// game plugin - ez2 w/ sdl
// 9 Aug 2026

game_plugin := EnginePlugin.{
	name = "game",
	proc_start 	= game_start,
	proc_end 	= game_end,
	proc_update = game_update,
	proc_render = game_render,
};

texture : *SDL_Texture;

game_start :: (){
	log("game start");
	surface := SDL_LoadBMP("assets/noita.bmp");
	//surface := SDL_LoadBMP("assets/default.png");

	if surface == null {
		log_error("[GAME] Failed to create surface: %", to_string(SDL_GetError()));
		return;
	}

	texture = SDL_CreateTextureFromSurface(window.renderer, surface);
	assert(texture != null);
}

game_end :: (){
	log("game end");
}

game_update :: (dt : float) {
	//ImGui.SetNextWindowPos(.{0, 0});
	ImGui.Begin("Game Window");

	ImGui.Text("Hello, world!");
	ImGui.TextColored(GREEN, "Hello, jai-style print: %, %!", 25, "Striiing"); 
	ImGui.TextColored(RED, "Hello, colored print world: %, %!", 25, "Striiing");
	ImGui.TextDisabled("Disbled formatted text: %, %!", 25, "Striiing");
	//ImGui.SliderFloat("float", *f, 0.0, 1.0, "%.3f");  // Edit 1 float as a slider from 0.0f to 1.0f
	//ImGui.ColorEdit3("clear color", *clear_color.xyz.component);  // Edit 3 floats as a color
	//if ImGui.Button("Demo Window", size=.{0,0}) show_demo_window ^= true;       // Use buttons to toggle our bools. We could use Checkbox() as well.
	//if ImGui.Button("Another Window", size=.{0,0}) show_another_window ^= true;
	//ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate);

	if ImGui.Button("TEST") {
		log("button test");
	}
	ImGui.End();
}

game_render:: (dt : float){
	//r := cast(u8)(config.bg.x*255);
	//g := cast(u8)(config.bg.y*255);
	//b := cast(u8)(config.bg.z*255);
	//a := cast(u8)(config.bg.w*255);
	//SDL_SetRenderDrawColor(window.renderer, r, g, b, a);
	//SDL_RenderClear(window.renderer);
//
	//dest : SDL_Rect;
	//dest.x = 0;
	//dest.y = 0;
	//dest.w = 64;
	//dest.h = 64;
	//SDL_QueryTexture(texture, null, null, *dest.x, *dest.y);
	//SDL_RenderCopy(window.renderer, texture, null, *dest);
//
	////rect := SDL_Rect.{20, 20, 100, 100};
	////SDL_RenderDrawRect(window.renderer, *rect);
	//SDL_RenderPresent(window.renderer);
}
