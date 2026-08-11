// build.jai - Clip Browser
// 10 April 2026
// 
//Start with run.bat to build and launch the game.
// Options
// >run.bat
// >run.bat editor


EXE_NAME := "ez";
OUTPUT_PATH := "";

TARGET_PLUGIN :: #string DONE
STARTUP_PLUGIN :: "game";
DONE

DEFINE_DEVELOPER_ON :: #string DONE
DEVELOPER :: true; 
DONE

DEFINE_DEVELOPER_OFF :: #string DONE
DEVELOPER :: false; 
DONE

DEFINE_WAIT_FOR_DEBUGGER_ON :: #string DONE
WAIT_FOR_DEBUGGER :: true;
DONE

DEFINE_WAIT_FOR_DEBUGGER_OFF :: #string DONE
WAIT_FOR_DEBUGGER :: false;
DONE

#run {
	workspace := compiler_create_workspace("Target workspace");
	options := get_build_options(workspace);
	options.output_executable_name = EXE_NAME;
	options.output_path = OUTPUT_PATH;
	set_build_options(options, workspace);

	compiler_begin_intercept(workspace);
    add_build_file("src/main.jai", workspace);
    set_build_options_dc(.{do_output=false});

    // parse for our starting plugin
    args := options.compile_time_command_line;
    set_default_plugin := false;

    // DEVELOPER by default
    dev_define := DEFINE_DEVELOPER_ON;

    wait_for_debugger := false;

    for arg: args {
    	print("arg=%\n", arg);
        if arg == {
          //case "game";
          //	add_build_string(TARGET_PLUGIN_GAME, workspace);
          //	print("Building for plugin: [game]\n");
          //	set_default_plugin = true;

          case "release";
            dev_define = DEFINE_DEVELOPER_OFF;

          case "wait_for_debugger";
            wait_for_debugger = true;
        }
    }

    if !set_default_plugin {
    	add_build_string(TARGET_PLUGIN, workspace);
      print("Building for plugin: [browser]\n");
    }

    if wait_for_debugger {
      add_build_string(DEFINE_WAIT_FOR_DEBUGGER_ON, workspace);
    }
    else {
      add_build_string(DEFINE_WAIT_FOR_DEBUGGER_OFF, workspace);
    }

    print("Build define [%]\n", dev_define);
    add_build_string(dev_define, workspace);

    compiler_end_intercept(workspace);
};

#import "Basic";
#import "Compiler";