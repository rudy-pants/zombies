Goal:

I want to create a single-player first-person shooter 3D game stored in a single HTML file, where a player navigates a map facing different types of enemies, and then reaches a boss room where they need to find and kill a boss. I want it to have a space setting. I want some ideas for level design. The player should be able to double-jump, have a pistol that shoots bullets, and have a special propulsion cannon that takes 3 seconds to load, and shoots an energy orb that launches movable entities on impact. There should be small enemies that crawl fast, pand weigh half the size of the human player. There should be player-sized enemies that fire back at players, who weigh slightly less than a human. There should be a boss that is larger than a player, weighs double, has a lot of health, but should be slow moving and slow attacking. All enemies should take critical hit gdamage if the player shoots their head.

Physics considerations:

Come up with appropriate physics and optimizations for setting up a basic 3D game engine. The player should be able to move around with a feel that has acceleration and deceleration. Moving entities like players, enemies, and projectiles should have appropriate collision detection. Use object pooling and lookup tables for conserving memory. The game should run at 60 fps. Use WASD for movement, and the mouse for aiming, right click for zoom, and left click for shooting. What might a good map design befor this setup? I want map designs that allow the game to take full advantage of the features here, while not being too overcomplicated.

Issues with zombies_test2.html:
- Player doesn't move when WASD is pressed
- When bullets collide with the wall or an entity, they should disappear. Instead, the keep sliding and moving.
- The mouse aiming up and down directions are swapped. Moving the mouse to look up aims downwards instead. Change this.
- The chargable projectile should take 3 seconds to fully charge. When firing the projectile, nothing happens.
- Jumping appears to be screwed up: when the player jumps, the player is stuck in the air for a few seconds. It might be because the player spawns in a wall, but I'm not sure.
