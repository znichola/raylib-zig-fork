// raylib-zig port of https://github.com/raysan5/raylib/blob/master/examples/core/core_custom_frame_control.c
//
// *   NOTE: WARNING: This is an example for advanced users willing to have full control over
// *   the frame processes. By default, EndDrawing() calls the following processes:
// *       1. Draw remaining batch data: rlDrawRenderBatchActive()
// *       2. SwapScreenBuffer()
// *       3. Frame time control: WaitTime()
// *       4. PollInputEvents()
// *
// *   To avoid steps 2, 3 and 4, flag SUPPORT_CUSTOM_FRAME_CONTROL can be enabled in
// *   config.h (it requires recompiling raylib). This way those steps are up to the user.
// *
// *   Note that enabling this flag invalidates some functions:
// *       - GetFrameTime()
// *       - SetTargetFPS()
// *       - GetFPS()

const rl = @import("raylib");
const std = @import("std");

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - custom frame control");
    defer rl.closeWindow();

    // Custom timming variables
    var previousTime = rl.getTime(); // Previous time measure
    var currentTime: f64 = 0.0; // Current time measure
    var updateDrawTime: f64 = 0.0; // Update + Draw time
    var waitTime: f64 = 0.0; // Wait time (if target fps required)
    var deltaTime: f64 = 0.0; // Frame time (Update + Draw + Wait time)

    var timeCounter: f64 = 0.0; // Accumulative time counter (seconds)
    var position: f64 = 0.0; // Circle position
    var pause = false; // Pause control flag

    var targetFPS: i32 = 60; // Our initial target fps
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        rl.pollInputEvents(); // Poll input events (SUPPORT_CUSTOM_FRAME_CONTROL)

        if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
            pause = !pause;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_up)) {
            targetFPS += 20;
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_down)) {
            targetFPS -= 20;
        }
        if (targetFPS < 0) {
            targetFPS = 0;
        }

        if (!pause) {
            position += 200 * deltaTime; // We move at 200 pixels per second
            if (position >= @as(f64, @floatFromInt(rl.getScreenWidth()))) {
                position = 0;
            }
            timeCounter += deltaTime; // We count time (seconds)
        }
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.ray_white);

            for (0..@as(usize, @divTrunc(@as(usize, @intCast(rl.getScreenHeight())), 200))) |i| {
                rl.drawRectangle(@intCast(200 * i), 0, 1, rl.getScreenHeight(), rl.Color.sky_blue);
            }
            rl.drawCircle(@intFromFloat(position), @divTrunc(rl.getScreenHeight(), 2) - 25, 50, rl.Color.red);
            rl.drawText(rl.textFormat("%03.0f ms", .{timeCounter * 1000.0}), @as(i32, @intFromFloat(position)) - 40, @divTrunc(rl.getScreenHeight(), 2) - 100, 20, rl.Color.maroon);
            rl.drawText(rl.textFormat("PosX: %03.0f", .{position}), @as(i32, @intFromFloat(position)) - 50, @divTrunc(rl.getScreenHeight(), 2) + 40, 20, rl.Color.black);

            rl.drawText("Circle is moving at a constant 200 pixels/sec,\nindependently of the frame rate.", 10, 10, 20, rl.Color.dark_gray);
            rl.drawText("PRESS SPACE to PAUSE MOVEMENT", 10, rl.getScreenHeight() - 60, 20, rl.Color.gray);
            rl.drawText("PRESS UP | DOWN to CHANGE TARGET FPS", 10, rl.getScreenHeight() - 30, 20, rl.Color.gray);
            rl.drawText(rl.textFormat("TARGET FPS: %i", .{targetFPS}), rl.getScreenWidth() - 220, 10, 20, rl.Color.lime);
            rl.drawText(rl.textFormat("CURRENT FPS: %i", .{@as(i32, @intFromFloat(if (std.math.isNormal(deltaTime)) (1 / deltaTime) else 0))}), rl.getScreenWidth() - 220, 40, 20, rl.Color.green);
        }

        // NOTE: In case raylib is configured to SUPPORT_CUSTOM_FRAME_CONTROL,
        // Events polling, screen buffer swap and frame time control must be managed by the user

        rl.swapScreenBuffer(); // Flip the back buffer to screen (front buffer)

        currentTime = rl.getTime();
        updateDrawTime = currentTime - previousTime;
        defer previousTime = currentTime;

        if (targetFPS > 0) { // We want a fixed frame rate

            waitTime = (1.0 / @as(f64, @floatFromInt(targetFPS))) - updateDrawTime;

            if (waitTime > 0.0) {
                rl.waitTime(waitTime);
                currentTime = rl.getTime();
                deltaTime = currentTime - previousTime;
            }
        } else {
            deltaTime = updateDrawTime;
        }
    }
}
