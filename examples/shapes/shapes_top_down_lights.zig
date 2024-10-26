// ported from https://github.com/raysan5/raylib/blob/master/examples/shapes/shapes_top_down_lights.c

const rl = @import("raylib");
const gl = rl.gl;

// Custom Blend Modes
const RLGL_SRC_ALPHA = 0x0302;
const RLGL_MIN = 0x8007;
const RLGL_MAX = 0x8008;

const MAX_BOXES = 20;
const MAX_SHADOWS = MAX_BOXES * 3; // MAX_BOXES *3. Each box can cast up to two shadow volumes for the edges it is away from, and one for the box itself;
const MAX_LIGHTS = 16;

// Shadow geometry type
const ShadowGeometry = struct {
    vertices: [4]rl.Vector2,
};

// Light info type
const LightInfo = struct {
    active: bool, // Is this light slot active?
    dirty: bool, // Does this light need to be updated?
    valid: bool, // Is this light in a valid position?

    position: rl.Vector2, // Light position
    mask: rl.RenderTexture, // Alpha mask for the light
    outerRadius: f32, // The distance the light touches
    bounds: rl.Rectangle, // A cached rectangle of the light bounds to help with culling

    shadows: [MAX_SHADOWS]ShadowGeometry,
    shadowCount: usize,
};

var lights: [MAX_LIGHTS]LightInfo = undefined;

// Move a light and mark it as dirty so that we update it's mask next frame
fn moveLight(slot: usize, x: f32, y: f32) void {
    lights[slot].dirty = true;
    lights[slot].position.x = x;
    lights[slot].position.y = y;

    // update the cached bounds
    lights[slot].bounds.x = x - lights[slot].outerRadius;
    lights[slot].bounds.y = y - lights[slot].outerRadius;
}

// Compute a shadow volume for the edge
// It takes the edge and projects it back by the light radius and turns it into a quad
fn computeShadowVolumeForEdge(slot: usize, sp: rl.Vector2, ep: rl.Vector2) void {
    if (lights[slot].shadowCount >= MAX_SHADOWS) return;

    const extention = lights[slot].outerRadius * 2;

    const spVector = sp.subtract(lights[slot].position).normalize();
    const spProjection = sp.add(spVector.scale(extention));

    const epVector = ep.subtract(lights[slot].position).normalize();
    const epProjection = ep.add(epVector.scale(extention));

    lights[slot].shadows[lights[slot].shadowCount].vertices[0] = sp;
    lights[slot].shadows[lights[slot].shadowCount].vertices[1] = ep;
    lights[slot].shadows[lights[slot].shadowCount].vertices[2] = epProjection;
    lights[slot].shadows[lights[slot].shadowCount].vertices[3] = spProjection;

    lights[slot].shadowCount += 1;
}

// Draw the light and shadows to the mask for a light
fn drawLightMask(slot: usize) void {
    // Use the light mask
    rl.beginTextureMode(lights[slot].mask);
    defer rl.endTextureMode();

    rl.clearBackground(rl.Color.white);

    // Force the blend mode to only set the alpha of the destination
    gl.rlSetBlendFactors(gl.rl_src_alpha, gl.rl_src_alpha, gl.rl_min);
    gl.rlSetBlendMode(@intFromEnum(gl.rlBlendMode.rl_blend_custom));

    // If we are valid, then draw the light radius to the alpha mask
    if (lights[slot].valid) {
        rl.drawCircleGradient(
            @as(i32, @intFromFloat(lights[slot].position.x)),
            @as(i32, @intFromFloat(lights[slot].position.y)),
            lights[slot].outerRadius,
            rl.Color.alpha(rl.Color.white, 0),
            rl.Color.white,
        );
    }

    gl.rlDrawRenderBatchActive();

    // Cut out the shadows from the light radius by forcing the alpha to maximum
    gl.rlSetBlendMode(@intFromEnum(rl.BlendMode.blend_alpha));
    gl.rlSetBlendFactors(gl.rl_src_alpha, gl.rl_src_alpha, gl.rl_max);
    gl.rlSetBlendMode(@intFromEnum(rl.BlendMode.blend_custom));

    // Draw the shadows to the alpha mask
    for (0..lights[slot].shadowCount) |i| {
        rl.drawTriangleFan(&lights[slot].shadows[i].vertices, rl.Color.white);
    }

    gl.rlDrawRenderBatchActive();

    // Go back to normal blend mode
    gl.rlSetBlendMode(@intFromEnum(gl.rlBlendMode.rl_blend_alpha));
}

// Setup a light
fn setupLight(slot: usize, x: f32, y: f32, radius: f32) void {
    lights[slot].active = true;
    lights[slot].valid = false; // The light must prove it is valid
    lights[slot].mask = rl.loadRenderTexture(rl.getScreenWidth(), rl.getScreenHeight());
    lights[slot].outerRadius = radius;

    lights[slot].bounds.width = radius * 2;
    lights[slot].bounds.height = radius * 2;

    moveLight(slot, x, y);

    // Force the render texture to have something in it.
    drawLightMask(slot);
}

// See if a light needs to update it's mask
fn updateLight(slot: usize, boxes: []rl.Rectangle, count: usize) bool {
    if (!lights[slot].active or !lights[slot].dirty) return false;

    lights[slot].dirty = false;
    lights[slot].shadowCount = 0;
    lights[slot].valid = false;

    for (0..count) |i| {
        // Are we in a box? if so we are not valid
        if (rl.checkCollisionPointRec(lights[slot].position, boxes[i])) return false;

        // If this box is outside our bounds, we can skip it
        if (!rl.checkCollisionRecs(lights[slot].bounds, boxes[i])) continue;

        // Check the edges that are on the same side we are, and cast shadow volumes out from them

        // Top
        var sp = rl.Vector2.init(boxes[i].x, boxes[i].y);
        var ep = rl.Vector2.init(boxes[i].x + boxes[i].width, boxes[i].y);

        if (lights[slot].position.y > ep.y) computeShadowVolumeForEdge(slot, sp, ep);

        // Right
        sp = ep;
        ep.y += boxes[i].height;
        if (lights[slot].position.x < ep.x) computeShadowVolumeForEdge(slot, sp, ep);

        // Bottom
        sp = ep;
        ep.x -= boxes[i].width;
        if (lights[slot].position.y < ep.y) computeShadowVolumeForEdge(slot, sp, ep);

        // Left
        sp = ep;
        ep.y -= boxes[i].height;
        if (lights[slot].position.x > ep.x) computeShadowVolumeForEdge(slot, sp, ep);

        // The box itself
        lights[slot].shadows[lights[slot].shadowCount].vertices[0] = rl.Vector2.init(boxes[i].x, boxes[i].y);
        lights[slot].shadows[lights[slot].shadowCount].vertices[1] = rl.Vector2.init(boxes[i].x, boxes[i].y + boxes[i].height);
        lights[slot].shadows[lights[slot].shadowCount].vertices[2] = rl.Vector2.init(boxes[i].x + boxes[i].width, boxes[i].y + boxes[i].height);
        lights[slot].shadows[lights[slot].shadowCount].vertices[3] = rl.Vector2.init(boxes[i].x + boxes[i].width, boxes[i].y);
        lights[slot].shadowCount += 1;
    }

    lights[slot].valid = true;

    drawLightMask(slot);

    return true;
}

// Set up some boxes
fn setupBoxes(boxes: []rl.Rectangle, count: *usize) void {
    boxes[0] = rl.Rectangle.init(150, 80, 40, 40);
    boxes[1] = rl.Rectangle.init(1200, 700, 40, 40);
    boxes[2] = rl.Rectangle.init(200, 600, 40, 40);
    boxes[3] = rl.Rectangle.init(1000, 50, 40, 40);
    boxes[4] = rl.Rectangle.init(500, 350, 40, 40);

    for (5..MAX_BOXES) |i| {
        boxes[i] = rl.Rectangle.init(
            @as(f32, @floatFromInt(rl.getRandomValue(0, rl.getScreenWidth()))),
            @as(f32, @floatFromInt(rl.getRandomValue(0, rl.getScreenHeight()))),
            @as(f32, @floatFromInt(rl.getRandomValue(10, 100))),
            @as(f32, @floatFromInt(rl.getRandomValue(10, 100))),
        );
    }

    count.* = MAX_BOXES;
}

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [shapes] example - top down lights");

    // Initialize our 'world' of boxes
    var boxCount: usize = 0;
    var boxes: [MAX_BOXES]rl.Rectangle = undefined;
    setupBoxes(&boxes, &boxCount);

    // Create a checkerboard ground texture
    const img: rl.Image = rl.genImageChecked(64, 64, 32, 32, rl.Color.dark_brown, rl.Color.dark_gray);
    const backgroundTexture: rl.Texture2D = rl.loadTextureFromImage(img);
    defer rl.unloadTexture(backgroundTexture);
    rl.unloadImage(img);

    // Create a global light mask to hold all the blended lights
    const lightMask: rl.RenderTexture = rl.loadRenderTexture(rl.getScreenWidth(), rl.getScreenHeight());
    defer rl.unloadRenderTexture(lightMask);

    // Setup initial light
    setupLight(0, 600, 400, 300);
    var nextLight: usize = 1;

    var showLines = false;

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // Drag light 0
        if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) moveLight(0, rl.getMousePosition().x, rl.getMousePosition().y);

        // Make a new light
        if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_right) and (nextLight < MAX_LIGHTS)) {
            setupLight(nextLight, rl.getMousePosition().x, rl.getMousePosition().y, 200);
            nextLight += 1;
        }

        // Toggle debug info
        if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) showLines = !showLines;

        // Update the lights and keep track if any were dirty so we know if we need to update the master light mask
        var dirtyLights = false;
        for (0..MAX_LIGHTS) |i| {
            if (updateLight(i, &boxes, boxCount)) dirtyLights = true;
        }

        // Update the light mask
        if (dirtyLights) {
            // Build up the light mask
            rl.beginTextureMode(lightMask);
            defer rl.endTextureMode();

            rl.clearBackground(rl.Color.black);

            // Force the blend mode to only set the alpha of the destination
            gl.rlSetBlendFactors(gl.rl_src_alpha, gl.rl_src_alpha, gl.rl_min);
            gl.rlSetBlendMode(@intFromEnum(gl.rlBlendMode.rl_blend_custom));

            // Merge in all the light masks
            for (0..MAX_LIGHTS) |i| {
                if (lights[i].active) rl.drawTextureRec(lights[i].mask.texture, rl.Rectangle.init(
                    0,
                    0,
                    @as(f32, @floatFromInt(rl.getScreenWidth())),
                    @as(f32, @floatFromInt(-rl.getScreenHeight())),
                ), rl.Vector2.zero(), rl.Color.white);
            }

            gl.rlDrawRenderBatchActive();

            // Go back to normal blend
            gl.rlSetBlendMode(@intFromEnum(rl.BlendMode.blend_alpha));
        }
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        // Draw the tile background
        rl.drawTextureRec(backgroundTexture, rl.Rectangle.init(
            0,
            0,
            @as(f32, @floatFromInt(rl.getScreenWidth())),
            @as(f32, @floatFromInt(rl.getScreenHeight())),
        ), rl.Vector2.zero(), rl.Color.white);

        // Overlay the shadows from all the lights
        rl.drawTextureRec(lightMask.texture, rl.Rectangle.init(
            0,
            0,
            @as(f32, @floatFromInt(rl.getScreenWidth())),
            -@as(f32, @floatFromInt(rl.getScreenHeight())),
        ), rl.Vector2.zero(), rl.Color.alpha(rl.Color.white, if (showLines) 0.75 else 1.0));

        // Draw the lights
        for (0..MAX_LIGHTS) |i| {
            if (lights[i].active) rl.drawCircle(
                @as(i32, @intFromFloat(lights[i].position.x)),
                @as(i32, @intFromFloat(lights[i].position.y)),
                10,
                if (i == 0) rl.Color.yellow else rl.Color.white,
            );
        }

        if (showLines) {
            for (0..lights[0].shadowCount) |s| {
                rl.drawTriangleFan(&lights[0].shadows[s].vertices, rl.Color.dark_purple);
            }

            for (0..boxCount) |b| {
                if (rl.checkCollisionRecs(boxes[b], lights[0].bounds)) {
                    rl.drawRectangleRec(boxes[b], rl.Color.purple);
                }

                rl.drawRectangleLines(
                    @as(i32, @intFromFloat(boxes[b].x)),
                    @as(i32, @intFromFloat(boxes[b].y)),
                    @as(i32, @intFromFloat(boxes[b].width)),
                    @as(i32, @intFromFloat(boxes[b].height)),
                    rl.Color.dark_blue,
                );
            }

            rl.drawText("(F1) Hide Shadow Volumes", 10, 50, 10, rl.Color.green);
        } else {
            rl.drawText("(F1) Show Shadow Volumes", 10, 50, 10, rl.Color.green);
        }

        rl.drawFPS(screenWidth - 80, 10);
        rl.drawText("Drag to move light #1", 10, 10, 10, rl.Color.dark_green);
        rl.drawText("Right click to add new light", 10, 30, 10, rl.Color.dark_green);
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    for (0..MAX_LIGHTS) |i| {
        if (lights[i].active) rl.unloadRenderTexture(lights[i].mask);
    }
}
