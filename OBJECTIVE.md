Goal:

I want to create a single-player first-person shooter 3D game stored in a single HTML file, where a player navigates a map facing different types of enemies, and then reaches a boss room where they need to find and kill a boss. I want it to have a space setting. I want some ideas for level design. The player should be able to double-jump, have a pistol that shoots bullets, and have a special propulsion cannon that takes 3 seconds to load, and shoots an energy orb that launches movable entities on impact. There should be small enemies that crawl fast, pand weigh half the size of the human player. There should be player-sized enemies that fire back at players, who weigh slightly less than a human. There should be a boss that is larger than a player, weighs double, has a lot of health, but should be slow moving and slow attacking. All enemies should take critical hit gdamage if the player shoots their head.

Gameplay considerations:

There should be a start menu screen, a pause menu screen, and an endgame screen. The user's mouse should be locked during gameplay, but free during the menu screens.

The game should run at 60 fps. Use WASD for movement, the mouse for aiming (use regular mouse aim mode not inverted controls for flight systems), right click for zoom, and left click for shooting. Avoid the issue of gimbal lock by using quaternions for camera yaw vs pitch rotation.

Physics considerations:

Come up with appropriate physics and optimizations for setting up a basic 3D game engine. The player should be able to move around with a feel that has acceleration and deceleration. Moving physical entities like players, enemies, and projectiles should have appropriate collision detection. Projectiles should be destroyed on impact, while players and enemies should slide against walls. Use object pooling and lookup tables for conserving memory.

Double-jumping should work properly when the player is in the air. Handle collisions when jumping onto walls or different platforms.

Create a simple platform-based map where the player must jump between platforms to fight different enemies. Movement will be a crucial part of this game.

Issues with zombies_test2.html:
- Player doesn't move when WASD is pressed
- When bullets collide with the wall or an entity, they should disappear. Instead, the keep sliding and moving.
- The mouse aiming up and down directions are swapped. Moving the mouse to look up aims downwards instead. Change this.
- The chargable projectile should take 3 seconds to fully charge. When firing the projectile, nothing happens.
- Jumping appears to be screwed up: when the player jumps, the player is stuck in the air for a few seconds. It might be because the player spawns in a wall, but I'm not sure.

Issues
