// Port of worl to screen, Oct 2024 by znicholas
// port of https://github.com/raysan5/raylib/blob/master/examples/core/core_world_screen.c

const rl = @import("raylib");

pub fn main() anyerror!void {

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - core world screen");
    defer rl.closeWindow();

    // Define the camera to look into our 3d world
    var camera = rl.Camera{
        .position = rl.Vector3.init(10, 10, 10),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45,
        .projection = rl.CameraProjection.camera_perspective,
    };

    const cubePosition = rl.Vector3.zero();
    var cubeScreenPosition = rl.Vector2.zero();

    rl.disableCursor(); // Limit cursor to relative movement inside the window

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        rl.updateCamera(&camera, rl.CameraMode.camera_third_person);

        // Calculate cube screen space position (with a little offset to be in top)
        cubeScreenPosition = rl.getWorldToScreen(rl.Vector3.init(
            cubePosition.x,
            cubePosition.y + 2.5,
            cubePosition.z,
        ), camera);
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);
        {
            camera.begin();
            defer camera.end();

            rl.drawCube(cubePosition, 2, 2, 2, rl.Color.red);
            rl.drawCubeWires(cubePosition, 2, 2, 2, rl.Color.maroon);
            rl.drawGrid(10, 1);
        }

        rl.drawText(
            "Enemy: 100 / 100",
            @as(i32, @intFromFloat(cubeScreenPosition.x)) - @divTrunc(rl.measureText("Enemy: 100/100", 20), 2),
            @as(i32, @intFromFloat(cubeScreenPosition.y)),
            20,
            rl.Color.black, // This last comma forces the auto formatter to one line per argument
        );
        rl.drawText(
            rl.textFormat(
                "Cube position in screen space coordinates: [%i, %i]",
                .{
                    @as(i32, @intFromFloat(cubeScreenPosition.x)),
                    @as(i32, @intFromFloat(cubeScreenPosition.y)),
                },
            ),
            10,
            10,
            20,
            rl.Color.lime,
        );
        rl.drawText(
            "Text 2d should be always on top of the cube",
            10,
            40,
            20,
            rl.Color.gray,
        );
        //----------------------------------------------------------------------------------
    }
}
