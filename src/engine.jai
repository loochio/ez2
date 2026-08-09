/* engine.jai - Portable chunk between projects
v0.13 / started 9 August 2026
Forked from ez
jai version beta 0.2.028

~~ Features ~~
SDL implementation
plugins (game, editor, etc)
physics, collision detection
terminal + cheats
grids,  tilegrids
UI
2d rendering, textures
lua interpretter

*/

#import "Basic";
#import "System";
#import "File";
#import "File_Utilities";
#import "String";
#import "Math";
#import "Random";
#import "Hash_Table";
#import "Hash";

#import "Darkmoon"; // lua

#import "SDL";

//#import "Window_Creation"; @CLEAN
//#import "Input"; //@CLEAN

#import "Simp";
#import "GL";
#import "GetRect";
using Sound :: #import "Sound_Player"; //@CLEAN



EngineConfig :: struct {
	window_title : string = "Default";
	window_x := 0;
	window_y := 0;
	window_width := 640;
	window_height := 480;
	aspect : float; 
	bg_color := WHITE;
	world_width := 640;
	world_height := 480;
	font : string;
	default_texture : string;
	fps_target := 144;
	fps_unlimitted := false;
	vsync := true;
	plugins : [..] EnginePlugin;
	startup_plugin : string;
}
config : EngineConfig;

EngineProc 			:: #type ();
EngineProc_Update 	:: #type (dt : float);

EnginePlugin :: struct {
	name : string;
	proc_start 	: EngineProc;
	proc_end 	: EngineProc;
	proc_update	: EngineProc_Update;
	proc_render : EngineProc_Update;
}
active_plugin : *EnginePlugin;

WindowState :: struct {
	quit := false;
	wintype : Window_Type;
	width := 0;
	height := 0;
	center := Vector2.{};
	aspect := 1.0;
	camera : Camera;
}
window : WindowState;

// asset management
EnginePaths :: struct {
	exe : string;
	root : string;
	assets : string;
	textures : string;
	sound : string;
	shaders : string;
	config : string;
	levels : string;
	content : string;
	scripts : string; // prob needs to exist next to clip content
}
paths : EnginePaths;

Camera :: struct {
	using position := Vector2.{0,0};
	zoom := 1.0;
}

// tick updates
//@TODO move to WindowState
last_time:  float64;
fps_current : float = 0.;

// ui
//@TODO merge with our Hud :: struct declared below
hud_font : *Dynamic_Font;
hud_font_factor := 0.015; // scales the font height based on window size
hud_font_pixel_height := 0;
hud_current_theme: s32 = xx Default_Themes.Blood_Vampire;
hud_theme: Overall_Theme;

//@TODO create a new HUD for debug info
debug_ui_enabled := true; //@TODO probably clean this up
terminal_enabled := false;

// Input
//@TODO move to Input struct
mouse_pos_window : Vector2;
input_mod_ctrl := false;
input_mod_alt := false;
input_mod_shift := false;
ui_hit_this_frame := false;

// audio
//@TODO move to AudioState struct
mute := false;

DEFAULT_TEXTURE : Texture;

// Colors
WHITE 		:: Vector4.{1,1,1,1};
GREY 		:: Vector4.{.5,.5,.5,1};
BLACK 		:: Vector4.{0,0,0,1};
RED 		:: Vector4.{1,0,0,1};
ORANGE 		:: Vector4.{1,.5,0,1};
GREEN 		:: Vector4.{0,1,0,1};
BLUE 		:: Vector4.{0,0,1,1};
MAGENTA 	:: Vector4.{1,0,1,1};
YELLOW 		:: Vector4.{1,1,0,1};
CYAN 		:: Vector4.{0,1,1,1};


engine_run :: (cfg : EngineConfig) {
	log("Running ENGINE core\n");

	#if WAIT_FOR_DEBUGGER {
		time : s32 = 10000;
		log("Waiting for debugger, % (ms)\n", time);
		sleep_milliseconds(time);
	}

	config = cfg;
	
	//Path setup
	//@TODO make these folders if they do not exist
	paths.exe = get_path_of_running_executable();
	paths.root = path_strip_filename(paths.exe);
	paths.assets = join(paths.root, "assets");
	paths.textures = join(paths.assets, "/textures");
	paths.sound = join(paths.assets, "/sound");
	paths.config = join(paths.assets, "/config");
	paths.levels = join(paths.assets, "/levels");
	paths.shaders = join(paths.assets, "/shaders");
	paths.content = join(paths.assets, "/content");
	paths.scripts = join(paths.assets, "/scripts");


	// Window management
	SDL_Init(SDL_INIT_VIDEO);

	window := SDL_CreateWindow("An SDL2 window",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, config.window_width, config.window_height,
        SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN);

	//window = .{};
	//window.wintype = create_window(window_name=cfg.window_title, 
	//	width=config.window_width, height=config.window_height,
	//	window_x = cfg.window_x, window_y = cfg.window_y);

	//set_render_target(window.wintype);

	// Sound
	sound_player_init(.{update_from_a_thread = true});

	// load a global default texture
	if !is_empty(*config.default_texture) {
		path := tprint("%/%", paths.assets, config.default_texture);
		texture_load_from_file(*DEFAULT_TEXTURE, path);
	}

	{ // GetRect initialization
		ui_init();
		proc := default_theme_procs[hud_current_theme];
	    hud_theme = proc();
	    set_default_theme(hud_theme);
	    hud_init();
	}
	
	window_resize(config.window_width, config.window_height);

	//@TODO put behind a runtime config, not sure what that default value needs to be
	if !config.vsync {
		wglSwapIntervalEXT(0);
	}

	register_commands();
	set_plugin(config.startup_plugin);

	while !window.quit {
		reset_temporary_storage();
	
		update_window_events();
		for event : events_this_frame {
			if event.type == .QUIT || is_input_pressed(.ESCAPE) {
	            window.quit = true;
	            break;
	        }
			getrect_handle_event(event);
	    }

		// window resizing
		for get_window_resizes() {
            update_window(it.window);
            if it.window == window.wintype {
            	window_resize(it.width, it.height);
            }
        }
    	update_mouse();

    	// ~~~ Time ~~~
		time := seconds_since_init();
    	dt := cast(float)(time - last_time);
    	DT_MAX : float : 0.15;
    	dt = clamp(dt, 0, DT_MAX);
    	last_time = time;
    	fps_current = 1 / dt;

    	// UI UPDATE - All UI rendering/polling needs to be handled after this point
    	ui_hit_this_frame = false;
		ui_per_frame_update(window.wintype, xx window.width, xx window.height, time);
		hud_per_frame_update();

	    // ~~~ Input (Engine Level) ~~~ 
	    input_mod_ctrl = is_input_down(.CTRL);
	    input_mod_alt = is_input_down(.ALT);
	    input_mod_shift = is_input_down(.SHIFT);

	    //@TODO softcode custom input into .ini maybe?
	    // global hotkey map. printable with terminal "hotkeys"
		if is_input_pressed(96 /*`*/)  	{ 
			terminal_enabled = !terminal_enabled;
			terminal_id += 1;
		}

		// ~~~ Tick ~~~
		// block input while the terminal is open
    	if !terminal_enabled {
    		active_plugin.proc_update(dt);
    	}

		// ~~~ Rendering ~~~ 
		clear_render_target(config.bg_color.x, config.bg_color.y, config.bg_color.z, config.bg_color.w);
		active_plugin.proc_render(dt);

		debug_ui();
		terminal_rendering();
		swap_buffers(window.wintype);

    	Sound.update();

		//@TODO proper fps
		//https://github.com/QuattroMusic/6502-Simulator/blob/main/src/engine/core.jai#L49-L65
		if !config.fps_unlimitted {
			delay : s32 = cast(s32)((1.0 / config.fps_target) * 1000);
			sleep_milliseconds(delay);
		}
	}

	log("Teardown ENGINE core\n");
	sound_player_shutdown();
	active_plugin.proc_end();
}

debug_ui :: () {
	#if !DEVELOPER return;
	if !debug_ui_enabled return;

	debug_ui :: (line : s64, text : string) {
		ui_text_line(line, text, horizontal_anchor=.Right, color=RED);
	}
	
	debug_ui(1, "Engine UI");
	debug_ui(2, tprint("fps=%", formatFloat(fps_current, trailing_width=2)));
	debug_ui(3, tprint("width=%", window.width));
	debug_ui(4, tprint("height=%", window.height));
	debug_ui(5, tprint("aspect=%", window.aspect));
	debug_ui(6, tprint("camera=%", window.camera.position));
	debug_ui(7, tprint("zoom=%", window.camera.zoom));
	debug_ui(8, tprint("plugin=%", active_plugin.name));
}

// ~~~ @Plugins ~~~~

set_plugin :: (plugin : string) {
	prev := active_plugin;
	for config.plugins {
		if plugin == it.name {
			active_plugin = *it;
			break;
		}
	}

	if prev != null {
		log("Plugin exiting from [%]\n", prev.name);
		prev.proc_end();
	}

	log("Plugin init [%]\n", active_plugin.name);
	load_configs(plugin);
	active_plugin.proc_start();
}


// plugin .ini settings
load_configs :: (name : string) {
	path := tprint("%/%.ini", paths.config, name);
	buffer, success := read_entire_file(path);
	defer(free(buffer));

	if !success {
		log_error("Failed to load config: %\n", path);
		return;
	}

	lines := split(buffer, "\n");
	for lines {
		line := trim(it);

		if line.count == 0 continue;
		if begins_with_nocase(line, "#") continue;

		statement := split(line, "=");

		if statement.count != 2 {
			log_error("\t[ERROR] malformed line: %\n", line);
			continue;
		}

		key := statement[0];
		value := trim(statement[1]);
	}

	log("~~~ Loaded configs: % ~~~\n", path);
}

//@TODO section configs
get_config :: (plugin : string, key : string) -> string {
	return "UNDEFINED";
}


// ~~~~~~~ @Input ~~~~~~~ 

//@TODO wrap our own button definitions around Key_Code
is_input_pressed :: (key : Key_Code, consume_input := false) -> bool {
	result := input_button_states[key] & .START != 0;

	if result && consume_input {
		input_button_states[key] &= ~.START;
	}

	return result;
}

is_input_down :: (key : Key_Code) -> bool {
	return input_button_states[key] & .DOWN != 0;
}

is_input_released :: (key : Key_Code) -> bool {
	return input_button_states[key] & .END != 0;
}

update_mouse :: (){
	x, y, success := get_mouse_pointer_position();
	if success {
		mouse_pos_window.x = cast(float)x;
		mouse_pos_window.y = cast(float)(window.height - y); // invery mouse y to start at bottom
	}
}

// ~~~~~~~ @Window Management ~~~~~~~ 
window_resize :: (width : s64, height : s64) {
	if width == window.width && height == window.height { return; }

	window.width = width;
	window.height = height;
	window.center = Vector2.{window.width/2., window.height/2.};
	window_camera_center();

	aspect := window.width / cast(float)window.height;
	if aspect > config.aspect {
		window.aspect = window.height / cast(float)config.world_height;
	}
	else {
		window.aspect = window.width / cast(float)config.world_width;
	}

	// update ui data
	hud_font_pixel_height = cast(s64)(window.height * hud_font_factor);
	hud_font = get_font_at_size(paths.assets, config.font, hud_font_pixel_height);
    assert(hud_font != null);
}

window_camera_zoom :: (amount : float) {
	window.camera.zoom += amount;
	WINDOW_ZOOM_MAX :: 10.0;
	window.camera.zoom = clamp(window.camera.zoom, 0.1, WINDOW_ZOOM_MAX);
}

window_camera_center :: () {
	window.camera.position = window.center;
}

window_camera_move :: (pos : Vector2, scale_with_zoom := true) {
	dv := ifx scale_with_zoom then pos * window.camera.zoom else pos;
	window.camera.position += dv;
}

window_camera_zoom_reset :: () {
	window.camera.zoom = 1.;
}

scalar_to_window :: (value : float) -> float {
	return value * window.aspect * window.camera.zoom;
}

vec_to_window :: (window_pos : Vector2) -> Vector2 {
	result := window_pos;
	result.x = scalar_to_window(window_pos.x);
	result.y = scalar_to_window(window_pos.y);
	result.x += window.camera.x;
	result.y += window.camera.y;
	return result;
}


// ~~~~~~~ @Strings ~~~~~~~ 

string_reset :: (str : *string) {
	if str.count free(str.data);
	str.count = 0;
}

is_empty :: (str : *string) -> bool {
	return str.count == 0;
}

URL_PREFIX :: string.[
	"http://", 
	"https://",
	"ftp://"
];

is_url :: (path : string) -> bool {
	for URL_PREFIX {
		if begins_with(path, it) return true;
	}
	return false;
}

// ~~~~~~~ @Math / Collision ~~~~~~~ 

Transform :: struct {
	using pos : Vector3;
	scale : Vector3 = .{1,1,1};
	rotation : float;
}

Box :: struct {
	x : float = 0;
	y : float = 0;
	w : float = 0;
	h : float = 0;
}

AABB :: struct {
	lower : Vector2;
	upper : Vector2;
}

Collider :: struct {
	type := ColliderType.Inactive;
	shape := ColliderShape.Circle;
	size : Vector2;
	flags : ColliderFlags;
	enabled := true;
	asleep := false;

	//@TODO maybe store in global map so we don't need to set this for every collider
	is_a : ColliderMask;
	collides_with : ColliderMask;
}

ColliderType :: enum u8 {
	Inactive;
	Static;
	Dynamic;
	Kinematic;
	Trigger;
}

ColliderShape :: enum u8 {
	Circle;
	Box; //@TODO
}

ColliderMask :: enum_flags u8 {
	Pawn;
	Wall;
	Hero;
}

ColliderFlags :: enum_flags u8 {
	//Enabled; @TODO add these eventually
	//Asleep;
	Overlapping;
}

collider_reset :: (c : *Collider) {
	c.type = ColliderType.Inactive;
	c.shape = ColliderShape.Circle;
	c.size = Vector2.{0,0};
	c.enabled = true;
	c.asleep = false;
	c.is_a = 0;
	c.collides_with = 0;
}

is_overlap :: (apos : Vector2, a : *Collider, bpos : Vector2, b : *Collider) -> bool{
	if !b.enabled return false;
	if b.type == .Inactive return false;
	if a.is_a & b.collides_with == 0 return false;

	if a.shape == .Circle && b.shape == .Circle {
		return is_overlap_circle(apos, a.size.x, bpos, b.size.x);
	}

	if a.shape == .Box && b.shape == .Box {
		//@TODO
		//return is_overlap_aabb();
	}

	if a.shape == .Circle && b.shape == .Box {
		return is_overlap_circle_box(apos, a.size.x, bpos, b.size);
	}
	if b.shape == .Circle && a.shape == .Box {
		return is_overlap_circle_box(bpos, b.size.x, apos, a.size);
	}

	assert(false, "Unsupported combo, a=% b=%", a.shape, b.shape);
	return false;
}

is_in_circle :: (pos : Vector2, circle_center : Vector2, radius : float) -> bool {
	dist2 := distance_squared(pos, circle_center);
	return dist2 < (radius*radius);
}

is_overlap_circle :: (c0 : Vector2, r0 : float, c1 : Vector2, r1 : float) -> bool {
	dist := distance(c0, c1);
	return dist < (r0 + r1);
}

//@TODO
is_overlap_aabb :: (box0 : AABB, box1 : AABB) -> bool {
	return false;
}

is_overlap_circle_box :: (p0 : Vector2, r0 : float, p1 : Vector2, size1 : Vector2) -> bool{
	edge_x := clamp(p0.x, p1.x-size1.x/2., p1.x+size1.x/2.);
	edge_y := clamp(p0.y, p1.y-size1.y/2., p1.y+size1.y/2.);
	dx := p0.x - edge_x;
	dy := p0.y - edge_y;
	dist2 := dx*dx + dy*dy;
	return dist2 <= (r0*r0);
}

is_in_box :: (pos : Vector2, box : Box) -> bool {
	return pos.x > box.x-box.w/2. && pos.x < box.x+box.w/2.
		&& pos.y > box.y-box.h/2. && pos.y < box.y+box.h/2.;
}

get_box_intersection :: (a : Box, b : Box) -> bool, Box {
	xmin := max(a.x-a.w/2., b.x-b.w/2.);
	xmax := min(a.x+a.w/2., b.x+b.w/2.);
	ymin := max(a.y-a.h/2., b.y-b.h/2.);
	ymax := min(a.y+a.h/2., b.y+b.h/2.);

	if xmin < xmax && ymin < ymax {
		w := xmax-xmin;
		h := ymax-ymin;
		return true, Box.{xmin+w/2., ymin+h/2., w, h};
	}
	return false, Box.{};
}

linear_move :: (position : *Vector2, velocity : *Vector2, dt : float) {
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
}

is_nearly_zero :: (value : float) -> bool {
	return value < EPSILON && value > -EPSILON;
}

is_nearly_equal :: (a : float, b : float) -> bool {
	return abs(a-b) < EPSILON;
}

vec2 :: (v : Vector3) -> Vector2 {
	return Vector2.{v.x, v.y};
}

// ~~~ Graphics ~~~

ShaderSolid :: enum u32 {
	Color;
	ColorNoBlend;
}

ShaderTexture :: enum u32 {
	Default;
}

set_shader :: (shader := ShaderSolid.Color) {
	if shader== {
		case .Color; 		set_shader_for_color(true);
		case .ColorNoBlend; set_shader_for_color(false);
	}
}

set_shader :: (texture : *Texture, shader := ShaderTexture.Default) {
	assert(texture != null);
	if shader== {
		case .Default;
			assert(texture != null);
			set_shader_for_images(texture);

			//@MOD in Simp for sharp edges
			// Sim/backend/gl.jai, backend_set_texture(..)
			//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			//glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
}

set_uniform :: (shader: *Shader, name: *u8, value : float) {
    loc := glGetUniformLocation(shader.gl_handle, name);
    if loc >= 0  glUniform1f(loc, value);
}

set_attribute :: (shader: *Shader, name: *u8, value : Vector4) {
    loc := glGetAttribLocation(shader.gl_handle, name);
    if loc >= 0  glUniform4f(loc, value.x, value.y, value.z, value.w);
}

draw_square :: (pos_window : Vector2, size : Vector2, color : Vector4, type := ShaderSolid.Color) {
	//set_shader(type); @TODO shaders
    h := Vector2.{size.x * .5, 0};
    v := Vector2.{0, size.y * .5};
	p0 := pos_window - h - v;
    p1 := pos_window + h - v;
    p2 := pos_window + h + v;
    p3 := pos_window - h + v;
    immediate_quad(p0, p1, p2, p3, color);
}

draw_square :: (box : Box, color : Vector4, type := ShaderSolid.Color) {
	draw_square(Vector2.{box.x, box.y}, Vector2.{box.w, box.h}, color, type);
}

draw_box :: (box : Box, color : Vector4, thickness := 2.) {
	t := thickness;
	draw_square(.{box.x + box.w/2, box.y}, .{t, box.h}, color);
	draw_square(.{box.x - box.w/2, box.y}, .{t, box.h}, color);
	draw_square(.{box.x, box.y+box.h/2}, .{box.w, t}, color);
	draw_square(.{box.x, box.y-box.h/2}, .{box.w, t}, color);
}

draw_rect :: (r : Rect, color : Vector4) {
	draw_square(.{r.x+r.w/2.,r.y+r.h/2.}, .{r.w, r.h}, color);
}

// mostly copied from GetRect/color_picker.jai, draw_hsv_circle()
draw_circle :: (center_window : Vector2, radius_outer : float, radius_inner : float = 0, color : Vector4,
		percent_begin := 0.) 
{
	set_shader();
	NUM_SEGMENTS :: 16;
	last_p0, last_p1: Vector2 = ---;

	for i: 0..NUM_SEGMENTS - 1 {
        t := i / cast(float)(NUM_SEGMENTS - 1);

        // start from 12 oclock
        radians := TAU * (t+.25);
        dir := Vector2.{cos(radians), sin(radians)};

        p0 := center_window + dir * radius_outer;
        p1 := center_window + dir * radius_inner;

        // omit percentage of the circle
        if (i != 0 && t > percent_begin) {
        	immediate_triangle(to_vec3(last_p0), to_vec3(last_p1), to_vec3(p1), color, color, color);
            immediate_triangle(to_vec3(last_p0), to_vec3(p1), to_vec3(p0), color, color, color);
        }

        last_p0 = p0;
        last_p1 = p1;
    }
}

draw_collider :: (collider : *Collider, window_pos : Vector2, win_size : Vector2) {
	c := BLUE;
	if collider.type == {
		case .Dynamic; c = MAGENTA;
		case .Trigger; c = YELLOW;
		case .Inactive; c= WHITE;
	}
	if !collider.enabled c = RED;

	p := window_pos;
	if collider.shape== {
		case .Circle; {
			r := win_size.x;
			draw_circle(p, radius_outer=r, radius_inner=r-2, color=c);
		}
		case .Box; {
			box := Box.{p.x, p.y, win_size.x, win_size.y};
			draw_box(box, c);
		}
	}
}

draw_texture :: (texture : *Texture, window_pos : Vector2, scale := Vector2.{1,1}, outline := false, shader := ShaderTexture.Default, tint := WHITE) {
	width := texture.width * scale.x;
	height := texture.height * scale.y;

	if outline {
		draw_box(.{window_pos.x, window_pos.y, width, height}, RED);
	}

	h := Vector2.{width*.5, 0};
    v := Vector2.{0, height*.5};
	p0 := window_pos - h - v;
    p1 := window_pos + h - v;
    p2 := window_pos + h + v;
    p3 := window_pos - h + v;
	set_shader(texture, shader);
    immediate_quad(p0, p1, p2, p3, tint);
}

draw_texture_desired :: (texture : *Texture, window_pos : Vector2, desired : Vector2, outline := false, shader := ShaderTexture.Default, tint := WHITE) {
	ds := Vector2.{ desired.x / texture.width, desired.y / texture.height }; 
	draw_texture(texture, window_pos, scale = ds, outline, shader, tint);
}


// ~~~ Sound ~~~

toggle_mute :: () {
	if mute {
		log("~~~ Sound UNMUTED ~~~\n");
		mute = false;
		set_master_volume(1);
	}
	else {
		log("~~~ Game MUTED ~~~\n");
		mute = true;
		set_master_volume(0);
	}
}


// ~~~ @Pooling @Memory ~~~
// Memory management, we pool everything in with statically defined arrays.
//
//@TODO we need to come back and bulletproof add/removal
// there was a bug where items weren't removed.
// It ended up being a missing is_valid(..) but it still looked like there could be a general issue.
// Let's not forget and wait until a version gets shipped to real users to find out.

Pool :: struct (T : Type, size : s64) {
	values : [size] T;
	occupied : [size] bool;
	head := 0; //@TODO prob remove, always keep this head at 0
	tail := 0;
}

pool_reset :: (using pool : *Pool) {
	tail = 0;
	for occupied occupied[it_index] = false;
	for values values[it_index] = .{};
}

// fast alloc, O(1) (best case) well sort of, we still do a (probably) unnecessary loop
pool_alloc :: (using pool : *Pool) -> *pool.T {
	first_pass := true;
	while tail < occupied.count {
		if occupied[tail] {
			tail += 1;

			// try scanning from the beginning once before failing
			if tail == occupied.count {
				if first_pass{
					first_pass = false;
					tail = head;
				}
				else {
					break;
				}
			}

			continue;
		}
		assert(tail < occupied.count); //ran out of memory, not sure how we want to handle this
		occupied[tail] = true;
		return *values[tail];
	}
	assert(false, "%", pool.T); // failed to alloc mem
	return null;
}

// Slow, linear lookup O(n)
pool_remove :: (pool : *Pool, value : *pool.T) {
	for pool {
		if it == value {
			pool.values[it_index] = .{};
			pool.occupied[it_index] = false;
			return;
		}
	}
	assert(false, "%", pool.T); // value not found
}

for_expansion :: (pool : *Pool, body : Code, flags : For_Flags) #expand {
	for idx : 0..pool.values.count-1 {
		if !pool.occupied[idx] continue;

		value := *pool.values[idx];
		if !is_valid(value) continue;

		`it := value;
		`it_index := idx;

		#insert body;
	}
}

// ~~~ @UI ~~~

update_ui_hit :: (r : *Rect) {
	ui_hit_this_frame |= is_inside(mouse_pos_window.x, mouse_pos_window.y, r);
}

// assumes r.h is our line height
ui_line :: (r : *Rect, line : s64, direction := 1) -> s64 {
	r.y += r.h * direction;
	return line+1;
}

Layout :: struct {
	root : Rect;
}

//@TODO
//HorizontalLayout :: struct {}
//GridLayout :: struct {}

VerticalLayout :: struct {
	#as using layout : Layout;
	line := 0;
	direction := VerticalGrowDirection.Up;
}

VerticalGrowDirection :: enum {
	Down; //@TODO need to get this working, based on pivot values
	Up;
}

ui_line :: (layout : *VerticalLayout) {
	dir := ifx layout.direction == .Up then 1 else -1;
	layout.line = ui_line(*layout.root, layout.line, dir);
}

ui_next :: (layout : *VerticalLayout) -> Rect {
	ui_line(layout);
	return layout.root; // root get's modified by ui_line(..)
}

ui_label :: (layout : *VerticalLayout, fmt : string, args : .. Any) {
	r := ui_next(layout);
	txt := tprint(fmt, ..args);
	//@TODO scuffed that we're doign this here but I'm lazy
	hud_theme.label_theme.alignment = Text_Alignment.Left;
	label(r, txt, *hud_theme.label_theme);
}

ui_label :: (r : Rect, fmt : string, args : .. Any) {
	txt := tprint(fmt, args);
	//@TODO scuffed that we're doign this here but I'm lazy
	hud_theme.label_theme.alignment = Text_Alignment.Left;
	label(r, txt, *hud_theme.label_theme);
}

GridLayout :: struct {
	#as using vert_layout : VerticalLayout;

	// represent some normalized % of width 
	// Ex. [ 0.5, 0.5, 1 ] -> 25% | 25% | 50%
	columns : []float;
	column_pct : [..]float; 
	column_rects : [..] Rect;
}

ui_grid_init :: (using lo : *GridLayout) {
	// calc normalized col percents
	total := 0.;
	for columns { total += it; }
	for columns { array_add(*column_pct, it / total); }

	// calc column rects
	xoffset := 0.;
	for column_pct {
		r : = Rect.{root.x+xoffset, root.y, root.w*it, root.h};
		array_add(*column_rects, r);
		xoffset += r.w;
	}
}

ui_grid_deinit :: (using lo : *GridLayout) {
	array_reset(*column_pct);
	array_reset(*column_rects);
}

ui_col :: (layout : *GridLayout, col := 0) -> Rect {
	assert(col >= 0 && col < layout.column_rects.count);
	r := layout.column_rects[col];
	r.y = r.h + r.h*layout.line;
	return r;
}

UIAnchor :: enum {
	Left;
	Right;
	Center;
}

ui_text_line :: (line : s64, format_string : string, args: .. Any, horizontal_anchor : UIAnchor = .Left, color : Vector4 = WHITE) {
	text := tprint(format_string, ..args);
	text_width := prepare_text(hud_font, text);

	text_x:= 0;
	if horizontal_anchor == {
		case .Left; 	text_x = 0;
		case .Right; 	text_x = window.width - text_width;
		case .Center; 	text_x = (window.width - text_width)/2;
	}
	

    text_y := window.height - hud_font.character_height * line;
    draw_prepared_text(hud_font, text_x, text_y, color);
}

Hud :: struct {
	line := 0;
}
hud : Hud;

hud_init :: () {
	hud = .{};
}

hud_per_frame_update :: () {
	hud.line = 0;
}

hud_text :: (format_string : string, args: .. Any, horizontal_anchor : UIAnchor = .Left, color : Vector4 = WHITE) {
	hud.line += 1;
	ui_text_line(hud.line, format_string, args, horizontal_anchor, color);
}


// ~~~~~ @Termianl ~~~~~

terminal_prompt : string;
terminal_id : s64;
terminal_auto_complete := Auto_Complete.{terminal_cmds_auto_complete, null};

TerminalCommand :: struct {
	text : string;
	proc : TerminalCmdProc;
}

terminal_cmds : [..] TerminalCommand;

TerminalCmdProc :: #type (cmd : TerminalCommand, args: .. Any);

terminal_cmds_auto_complete :: (input: string, data: *void) -> (results: [] string, longest_match_length: int) {
    results: [..] string;
    longest_match_length := 0;
    #if DEVELOPER {
    	for terminal_cmds {
	        count := begins_with_count(it.text, input);
	        if count == input.count {
	            array_add(*results, it.text);
	            longest_match_length = max(longest_match_length, input.count);
	        }
	        longest_match_length = max(longest_match_length, count);
	    }
    }
    return results, longest_match_length;
}

// copied from GetRect/example.jai
begins_with_count :: (str: string, prefix: string) -> int {
    for 0..prefix.count-1 {
        if it >= str.count return it;

        ca := to_lower(str[it]);
        cb := to_lower(prefix[it]);
        if ca != cb return it;
    }
    return prefix.count;
}

// Register a single command
register_cmd :: (text : string, proc : TerminalCmdProc) {
	// skip duplicates, @TODO not sure if we should log anything?
	for terminal_cmds { if it.text == text return; }

	cmd := TerminalCommand.{ text, proc };
	array_add(*terminal_cmds, cmd);
}

// Register all default commands with the engine
register_commands :: () {
	#if !DEVELOPER return;

	// Register all plugins with a default command matching the plugin name
	for config.plugins {
		register_cmd(it.name, (cmd : TerminalCommand, args: .. Any) { 
			set_plugin(cmd.text); 
		} );
	}

	register_cmd("help", (cmd : TerminalCommand, args: .. Any) {
		print("Registered Commands\n");
		for terminal_cmds {
			log("\t%\n", it.text);
		}
	});

	register_cmd("toggle_ui", (cmd : TerminalCommand, args: .. Any) { 
		debug_ui_enabled = !debug_ui_enabled; 
	});
	register_cmd("toggle_mute", (cmd : TerminalCommand, args: .. Any) { 
		toggle_mute(); 
	});
	register_cmd("fps", (cmd : TerminalCommand, args: .. Any) {  
		config.fps_unlimitted = !config.fps_unlimitted; 
	});
}

// Render terminal UI and command processing
terminal_rendering :: () {
	if !terminal_enabled  return;

	k := window.height * .1;
	w := cast(float)window.width;
	r := get_rect(0, 0, w, hud_font.character_height*1.35);
	text_theme := hud_theme.text_input_theme;
	text_theme.alignment = .Left;
	text_theme.font = hud_font;
	action, input := text_input(r, terminal_prompt, *text_theme, identifier=terminal_id, input_action=.ACTIVATE, auto_complete=terminal_auto_complete);
	// process console cheats
	if action & .ENTERED  {
		terminal_id += 1;
		terminal_prompt = "";
		found, cmd, args := split_from_left(input, " ");
		//@OPTIMIZE faster lookup with a hash map
		if found {
			for terminal_cmds { 
				if cmd == it.text {
					it.proc(it, args); 
					terminal_enabled = false;
					break;
				}
			}
		}
		else {
			for terminal_cmds { 
				if input == it.text {
					 it.proc(it);
					 terminal_enabled = false;
					 break;
				}
			}
		}
	}
}

// ~~~~ @Grids ~~~~

// Take from how_to/730_for_expansions
Grid :: struct (count_x: s64, count_y: s64, T: Type) {
    NUM_CELLS :: count_x*count_y;
    occupied : [NUM_CELLS] bool;
    values :   [NUM_CELLS] T;
}

grid_set :: (grid: *Grid, x: s64, y: s64, value: grid.T) {
    assert((x >= 0) && (x < grid.count_x));
    assert((y >= 0) && (y < grid.count_y));

    index := y*grid.count_x + x;
    grid.occupied[index] = true;
    grid.values[index] = value;
}

grid_remove :: (grid: *Grid, x: s64, y: s64) {
	assert((x >= 0) && (x < grid.count_x));
    assert((y >= 0) && (y < grid.count_y));

    index := y*grid.count_x + x;
    grid.occupied[index] = false;
    grid.values[index] = .{};
}

grid_get :: (grid : *Grid, x : s64, y : s64) -> grid.T {
	assert((x >= 0) && (x < grid.count_x));
    assert((y >= 0) && (y < grid.count_y));

    index := y*grid.count_x + x;
    return grid.values[index];
}

grid_occupied :: (grid : *Grid, x : s64, y : s64) -> bool {
	if x < 0 || x >= grid.count_x return false;
	if y < 0 || y >= grid.count_y return false;

    index := y*grid.count_x + x;
    return grid.occupied[index];
}

Coordinates :: struct {
    x, y: s64;
}

for_expansion :: (grid: Grid, body: Code, flags: For_Flags) #expand {
    for y: 0..grid.count_y-1 {
        for x: 0..grid.count_x-1 {
            index := y*grid.count_x + x;
            if !grid.occupied[index] continue;

            `it := grid.values[index];
            
            `it_index: Coordinates;  // Let's make a new type to provide as it_index.
            it_index.x = x;
            it_index.y = y;

            #insert body;
        }
    }
}

GridDirection :: enum_flags u8 {
	None 	:: 0;
	North 	:: 1;
	East 	:: 1<<1;
	South 	:: 1<<2;
	West 	:: 1<<3;
}

has_neighbor :: (grid : *Grid, x : s64, y : s64, direction : GridDirection) -> bool {
	result := true;
	if direction & .North 	{ result &= grid_occupied(grid, x, y+1); }
	if direction & .East 	{ result &= grid_occupied(grid, x+1, y); }
	if direction & .South 	{ result &= grid_occupied(grid, x, y-1); }
	if direction & .West 	{ result &= grid_occupied(grid, x-1, y); }
	return result;
}


// TileGrid layout of indices, represents the object that exists in the world
// id is mapped to a unique Tilemap
// index is looked up in a TileMap, Tilemap translates index to tex slice
TileGrid :: struct () {
	layers : [..] TileGridLayer;
	position : Vector2; // world position origin
	CELL_SIZE :: 32.0;
}

TileGridLayer :: struct {
	grid : Grid(MAX_TILEGRID_CELLS, MAX_TILEGRID_CELLS, TileGridEntry);
	name : string;
	flags : TileGridLayerFlags = 0;
}

TileGridEntry :: struct {
	id := 0; 			// tilemap id
	slice : u8 = 0; 	//[0-15] dependent on neighbors, determines slice of tilemap to draw
}

TileGridLayerFlags :: enum_flags u8 {
	Hidden :: 1;
}

TileMap :: struct {
	texture_guid : string;
	id := 0;
}

MAX_TILEGRID_CELLS :: 128;
MAX_TILEMAPS :: 32;
tilemaps : Table(s64, TileMap);

tilemaps_add :: (texture_guid : string, id : s64) -> *TileMap {
	assert(is_empty(*texture_guid));
	assert(!table_contains(*tilemaps, id), "id=%", id);
	tm := TileMap.{ 
		sprint(texture_guid), 
		id,
	};
	result := table_add(*tilemaps, id, tm);
	assert(result != null, "Texture GUID=% id=%", texture_guid, id);
	return result;
}

get_tilemap :: (id : s64) -> *TileMap{
	result := table_find_pointer(*tilemaps, id);
	assert(result != null, "Tilemap ID not found: %", id);
	return result;
}

is_valid_tilemap_id :: (id : s64) -> bool {
	return table_contains(*tilemaps, id);
}

is_valid :: (tg : *TileGrid) -> bool{
	return tg.layers.count > 0;
}

tilegrid_reset :: (tg : *TileGrid) {
	for * tg.layers {
		string_reset(*it.name);
	}
	array_reset(*tg.layers);
	tg.position = .{};
}

tilegrid_add_layer :: (tg : *TileGrid, name : string) {
	layer := array_add(*tg.layers);
	layer.name = sprint(name);
}

tilegrid_remove_layer :: (tg : *TileGrid, layer : s64) {
	assert(layer >= 0 && layer < tg.layers.count, "layer=%", layer);
	string_reset(*tg.layers[layer].name);
	array_unordered_remove_by_index(*tg.layers, layer);
}

tilegrid_clear_layer :: (tg : *TileGrid, layer : s64) {
	assert(layer >= 0 && layer < tg.layers.count, "layer=%", layer);
	for tg.layers[layer].grid {
		erase_tilegrid_cell(tg, layer, it_index.x, it_index.y);
	}
}

get_tilegrid_coords_from_pos :: (tg : *TileGrid, pos : Vector2) -> (x : s64, y : s64) {
	assert(is_pos_in_tilegrid(tg, pos));
	p := pos - tg.position;
	x := cast(s64)(p.x / tg.CELL_SIZE);
	y := cast(s64)(p.y / tg.CELL_SIZE);
	return x, y;
}

get_pos_in_tilegrid :: (tg : *TileGrid, x : s64, y : s64) -> Vector2 {
	result := Vector2.{
		(x+0.5) * tg.CELL_SIZE + tg.position.x,
		(y+0.5) * tg.CELL_SIZE + tg.position.y
	};
	assert(is_pos_in_tilegrid(tg, result), "result:% | %,%", result, x, y);
	return result;
}

is_pos_in_tilegrid :: (tg : *TileGrid, pos : Vector2) -> bool {
	assert(is_valid(tg));
	return pos.x >= tg.position.x 
		&& pos.y >= tg.position.y 
		&& pos.x <= tg.position.x+(tg.CELL_SIZE*tg.layers[0].grid.count_x)
		&& pos.y <= tg.position.y+(tg.CELL_SIZE*tg.layers[0].grid.count_y);
}

set_tilegrid_cell :: (tg : *TileGrid, layer : s64, x : s64, y : s64, tm_id : s64) {
	assert(is_valid(tg));
	assert(tm_id >= 0);
	assert(layer >= 0 && layer < tg.layers.count);

	if tm_id != 0 {
		assert(is_valid_tilemap_id(tm_id));

		entry := TileGridEntry.{tm_id, 0};
		grid_set(*tg.layers[layer].grid, x, y, entry);
		assert(grid_occupied(*tg.layers[layer].grid, x, y));
	}
	else {
		grid_remove(*tg.layers[layer].grid, x, y);
	}
	
	// update slice of all surrounding grid cells
	set_tilegrid_slice(tg, layer, x, y);
	set_tilegrid_slice(tg, layer, x+1, y);
	set_tilegrid_slice(tg, layer, x, y+1);
	set_tilegrid_slice(tg, layer, x-1, y);
	set_tilegrid_slice(tg, layer, x, y-1);
}

set_tilegrid_slice :: (tg : *TileGrid, layer : s64, x : s64, y : s64) {
	if !grid_occupied(*tg.layers[layer].grid, x, y) return;

	entry := grid_get(*tg.layers[layer].grid, x, y);
	entry.slice = get_tilegrid_slice(tg, layer, x, y);
	grid_set(*tg.layers[layer].grid, x, y, entry);
}

//@OPTIMIZE not sure if return-by-value is good idea here
get_tilegrid_entry :: (tg : *TileGrid, layer : s64, x : s64, y : s64) -> TileGridEntry {
	return grid_get(*tg.layers[layer].grid, x, y);
}

erase_tilegrid_cell :: (tg : *TileGrid, layer : s64, row : s64, col : s64) {
	set_tilegrid_cell(tg, layer, row, col, 0);
}

get_tilegrid_slice :: (tg : *TileGrid, layer : s64, x : s64, y : s64) -> u8 {
	grid := *tg.layers[layer].grid;
	if(has_neighbor(grid, x, y, .North|.East|.South|.West)) return 9;

	if(has_neighbor(grid, x, y, .North|.West|.South)) return 10;
	if(has_neighbor(grid, x, y, .North|.East|.South)) return 8;
	if(has_neighbor(grid, x, y, .East|.South|.West)) return 13;
	if(has_neighbor(grid, x, y, .North|.East|.West)) return 5;

	if(has_neighbor(grid, x, y, .West|.South)) return 14;
	if(has_neighbor(grid, x, y, .East|.South)) return 12;
	if(has_neighbor(grid, x, y, .North|.South)) return 11;
	if(has_neighbor(grid, x, y, .North|.West)) return 6;
	if(has_neighbor(grid, x, y, .North|.East)) return 4;
	if(has_neighbor(grid, x, y, .East|.West)) return 1;

	if (has_neighbor(grid, x, y, .North)) return 7;
	if (has_neighbor(grid, x, y, .East)) return 0;
	if (has_neighbor(grid, x, y, .South)) return 15;
	if (has_neighbor(grid, x, y, .West)) return 2;
	return 3;
}

tilegrid_shift_layer_up :: (tg : *TileGrid, layer : s64) -> (changed:bool, new_layer_index:s64){
	if layer == tg.layers.count-1 return false, layer;

	assert(layer >= 0 && layer < tg.layers.count-1, "%", layer);
	temp := tg.layers[layer];
	tg.layers[layer] = tg.layers[layer+1];
	tg.layers[layer+1] = temp;
	return true, layer+1;
}

tilegrid_shift_layer_down :: (tg : *TileGrid, layer : s64) -> (changed:bool, new_layer_index:s64){
	if layer == 0 return false, layer;

	assert(layer > 0 && layer <= tg.layers.count-1, "%", layer);
	temp := tg.layers[layer];
	tg.layers[layer] = tg.layers[layer-1];
	tg.layers[layer-1] = temp;
	return true, layer-1;
}

// ~~~ @Lua Interpreter ~~~

lua_init :: () -> *lua_State {
	log("[LUA] Initializing Runtime");
    state := luaL_newstate();
    luaL_openlibs(state);
    assert(state != null);
    return state;
}

lua_shutdown :: (state : *lua_State) {
    assert(state != null);
    lua_close(state);
    log("[LUA] shutdown");
}

lua_api_register :: (state : *lua_State, name : *u8, func : lua_CFunction) {
    assert(state != null);
    reg := luaL_Reg.{ name, func };
    luaL_register(state, "clip", *reg);
}

// Run a raw blob of .lua text 
lua_run :: (state : *lua_State, text : string) {
    assert(state != null);

    if is_empty(*text) {
    	log_error("[LUA] attempted to run empty string");
    	return;
    }

    ret := luaL_loadbuffer(state, text.data, xx text.count, "script");

    if lua_error(state, ret) {
    	return;
    }

    ret = lua_pcall(state, 0, LUA_MULTRET, 0);
    lua_error(state, ret);
}

// Run a .lua file from the full path
lua_run_file :: (state : *lua_State, path : string) {
    log("[LUA] run path=%", path);
    buffer, success := read_entire_file(path);

    if !success {
        log_error("[LUA] failed to read script file %", path);
        free(buffer);
        return;
    }

    lua_run(state, buffer);
}

// Run a .lua file from our "/assets/scripts" folder
lua_run_file_script :: (state : *lua_State, filename : string) {
	path := tprint("%/%", paths.scripts, filename);
    lua_run_file(state, path);
}

lua_error :: (state : *lua_State, value : s64) -> bool {
	if value == LUA_OK return false;

    err : string;
    len : u64;
    err.data = lua_tolstring(state, -1, *len);
    err.count = xx len;
    lua_settop(state, 0);

	LUA_LOGGING :: true;
	if LUA_LOGGING {
		log_error("[LUA][%] exec error err=%", lua_ret_to_string(value), err);
	}

    return true;
}

lua_ret_to_string :: (ret : s64) -> string {
    if ret== {
        case LUA_MULTRET;   return "MULTRET";
        case LUA_OK;        return "OK";
        case LUA_YIELD;     return "YIELD";
        case LUA_ERRRUN;    return "ERRRUN";
        case LUA_ERRSYNTAX; return "ERRSYNTAX";
        case LUA_ERRMEM;    return "ERRMEM";
        case LUA_ERRERR;    return "ERRERR";
        case LUA_ERRFILE;   return "ERRFILE";
    }
    return "INVALID";
}

lua_script_update :: (state : *lua_State, dt : float) {
    assert(state != null);

    //@TODO this needs to account for if the .lua doesn't have an update() callback
    // we error here otherwise

    lua_getfield(state, LUA_GLOBALSINDEX, "update");
    lua_pushnumber(state, dt);
    ret := lua_pcall(state, 1, 0, 0);
   	lua_error(state, ret);
}

lua_script_begin :: (state : *lua_State) {
    assert(state != null);

    //@TODO this needs to account for if the .lua doesn't have an update() callback
    // we error here otherwise

    lua_getfield(state, LUA_GLOBALSINDEX, "begin");
    ret := lua_pcall(state, 0, 0, 0);
    lua_error(state, ret);
}


//@TODO removed hardcoded filename, just inline the script text
lua_run_tests :: () {
    log("[LUA] Testing LUA init() -> test scripts -> shutdown()");

    state := lua_init();

    // Test 1 : load and run a script
    lua_run_file_script(state, "test.lua");

    // Test 2 : load script, execute a callback w/ return value in that script
    //#if 0 
    {
        lua_run_file_script(state, "test_callback.lua");
        lua_getfield(state, LUA_GLOBALSINDEX, "on_callback");
        lua_pushinteger(state, 10);
        err := lua_pcall(state, 1, 1, 0);
        if (err != LUA_OK) {
            log("[LUA] error %\n", err);
        }
        else {
            result := lua_tointeger(state, -1);
            log("[LUA] callback returned value: %\n", result);
        }
    }

    lua_shutdown(state);
}
