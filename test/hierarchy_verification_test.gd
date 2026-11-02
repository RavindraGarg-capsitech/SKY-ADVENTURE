extends SceneTree

func _init() -> void:
	print("==================================================")
	print("SKY ADVENTURE — Scene Hierarchy Refactoring Verification")
	print("==================================================")

	var level_scene = load("res://level/temporary_level.tscn")
	if level_scene == null:
		printerr("FAIL: Could not load level/temporary_level.tscn")
		quit(1)
		return

	var level = level_scene.instantiate()
	root.add_child(level)
	current_scene = level

	await process_frame
	await process_frame

	var stats = [0, 0] # [passed, total]

	var check = func(name: String, condition: bool, err_msg: String = ""):
		stats[1] += 1
		if condition:
			print("  [PASS] " + name)
			stats[0] += 1
		else:
			printerr("  [FAIL] " + name + " — " + err_msg)

	# 1. Check Core container & managers
	print("\n--- Verifying Core Architecture ---")
	var core = level.get_node_or_null("Core")
	check.call("Core node exists", core != null and core is Node)
	var wave_mgr = level.get_node_or_null("Core/WaveManager")
	check.call("Core/WaveManager exists", wave_mgr != null)
	var enemy_mgr = level.get_node_or_null("Core/EnemyManager")
	check.call("Core/EnemyManager exists", enemy_mgr != null)
	var reward_mgr = level.get_node_or_null("Core/RewardManager")
	check.call("Core/RewardManager exists", reward_mgr != null)
	var island_mgr = level.get_node_or_null("Core/IslandManager")
	check.call("Core/IslandManager exists", island_mgr != null)

	# Check IslandManager exports
	if island_mgr != null:
		check.call("IslandManager.bridge_sector_2 resolved", island_mgr.bridge_sector_2 != null)
		check.call("IslandManager.moving_platform resolved", island_mgr.moving_platform != null)

	# 2. Check World container & sub-containers
	print("\n--- Verifying World Architecture ---")
	var world = level.get_node_or_null("World")
	check.call("World node exists", world != null and world is Node3D)
	if world != null:
		check.call("World transform is identity", world.transform == Transform3D.IDENTITY)

	var world_env = level.get_node_or_null("World/WorldEnvironment")
	check.call("World/WorldEnvironment exists", world_env != null)
	var dir_light = level.get_node_or_null("World/DirectionalLight3D")
	check.call("World/DirectionalLight3D exists", dir_light != null)

	var islands = level.get_node_or_null("World/Islands")
	check.call("World/Islands container exists", islands != null and islands is Node3D)
	if islands != null:
		check.call("World/Islands transform is identity", islands.transform == Transform3D.IDENTITY)

	check.call("World/Islands/StartIsland_Grass exists", level.get_node_or_null("World/Islands/StartIsland_Grass") != null)
	check.call("World/Islands/ArenaIsland_Grass exists", level.get_node_or_null("World/Islands/ArenaIsland_Grass") != null)
	check.call("World/Islands/EastIsland_Grass exists", level.get_node_or_null("World/Islands/EastIsland_Grass") != null)
	check.call("World/Islands/PlatformSector2 exists", level.get_node_or_null("World/Islands/PlatformSector2") != null)
	check.call("World/Islands/BossSanctuary_Floor exists", level.get_node_or_null("World/Islands/BossSanctuary_Floor") != null)

	var bridges = level.get_node_or_null("World/Bridges")
	check.call("World/Bridges container exists", bridges != null and bridges is Node3D)
	if bridges != null:
		check.call("World/Bridges transform is identity", bridges.transform == Transform3D.IDENTITY)
	check.call("World/Bridges/SkyBridge_Seg1 exists", level.get_node_or_null("World/Bridges/SkyBridge_Seg1") != null)
	check.call("World/Bridges/WestBridge_Seg1 exists", level.get_node_or_null("World/Bridges/WestBridge_Seg1") != null)
	check.call("World/Bridges/BridgeSector2 exists", level.get_node_or_null("World/Bridges/BridgeSector2") != null)

	var moving_platforms = level.get_node_or_null("World/MovingPlatforms")
	check.call("World/MovingPlatforms container exists", moving_platforms != null and moving_platforms is Node3D)
	if moving_platforms != null:
		check.call("World/MovingPlatforms transform is identity", moving_platforms.transform == Transform3D.IDENTITY)
	check.call("World/MovingPlatforms/MovingPlatform1 exists", level.get_node_or_null("World/MovingPlatforms/MovingPlatform1") != null)
	check.call("World/MovingPlatforms/EastSteppingStone exists", level.get_node_or_null("World/MovingPlatforms/EastSteppingStone") != null)
	check.call("World/MovingPlatforms/WestBridge_Stepping1 exists", level.get_node_or_null("World/MovingPlatforms/WestBridge_Stepping1") != null)

	var clouds = level.get_node_or_null("World/Clouds")
	check.call("World/Clouds container exists", clouds != null and clouds is Node3D)
	check.call("World/Clouds/CloudsLayer1 exists", level.get_node_or_null("World/Clouds/CloudsLayer1") != null)

	var distant_islands = level.get_node_or_null("World/DistantIslands")
	check.call("World/DistantIslands container exists", distant_islands != null and distant_islands is Node3D)
	check.call("World/DistantIslands/DistantIsland1 exists", level.get_node_or_null("World/DistantIslands/DistantIsland1") != null)

	var decorations = level.get_node_or_null("World/Decorations")
	check.call("World/Decorations container exists", decorations != null and decorations is Node3D)

	# 3. Check Gameplay container & entities
	print("\n--- Verifying Gameplay Architecture ---")
	var gameplay = level.get_node_or_null("Gameplay")
	check.call("Gameplay container exists", gameplay != null and gameplay is Node3D)
	if gameplay != null:
		check.call("Gameplay transform is identity", gameplay.transform == Transform3D.IDENTITY)

	var player = level.get_node_or_null("Gameplay/Player")
	check.call("Gameplay/Player exists", player != null)
	var entities = level.get_node_or_null("Gameplay/Entities")
	check.call("Gameplay/Entities dynamic parent exists", entities != null and entities is Node3D)

	var spawn_points = level.get_node_or_null("Gameplay/SpawnPoints")
	check.call("Gameplay/SpawnPoints container exists", spawn_points != null and spawn_points is Node3D)
	check.call("Gameplay/SpawnPoints/MobSpawner3D exists", level.get_node_or_null("Gameplay/SpawnPoints/MobSpawner3D") != null)
	check.call("Gameplay/SpawnPoints/MobSpawner3D2 exists", level.get_node_or_null("Gameplay/SpawnPoints/MobSpawner3D2") != null)
	check.call("Gameplay/SpawnPoints/MobSpawner3D_East exists", level.get_node_or_null("Gameplay/SpawnPoints/MobSpawner3D_East") != null)
	check.call("Gameplay/SpawnPoints/MobSpawner3D_North exists", level.get_node_or_null("Gameplay/SpawnPoints/MobSpawner3D_North") != null)
	check.call("Gameplay/SpawnPoints/MobSpawner3D_South exists", level.get_node_or_null("Gameplay/SpawnPoints/MobSpawner3D_South") != null)

	var collectibles = level.get_node_or_null("Gameplay/Collectibles")
	check.call("Gameplay/Collectibles container exists", collectibles != null and collectibles is Node3D)
	check.call("Gameplay/Collectibles/PathCoin1 exists", level.get_node_or_null("Gameplay/Collectibles/PathCoin1") != null)

	var kill_plane = level.get_node_or_null("Gameplay/KillPlane")
	check.call("Gameplay/KillPlane exists", kill_plane != null and kill_plane is Area3D)

	# 4. Check UI container & interfaces
	print("\n--- Verifying UI Architecture ---")
	var ui = level.get_node_or_null("UI")
	check.call("UI container exists", ui != null and ui is Node)
	check.call("UI/HUD exists", level.get_node_or_null("UI/HUD") != null)
	check.call("UI/UpgradeModal exists", level.get_node_or_null("UI/UpgradeModal") != null)
	check.call("UI/PauseModal exists", level.get_node_or_null("UI/PauseModal") != null)
	check.call("UI/GameOverModal exists", level.get_node_or_null("UI/GameOverModal") != null)
	check.call("UI/HomeUI exists", level.get_node_or_null("UI/HomeUI") != null)
	check.call("UI/MobileUI exists", level.get_node_or_null("UI/MobileUI") != null)

	# 5. Check spawner discovery by EnemyManager
	print("\n--- Verifying Spawner & Manager Integration ---")
	if enemy_mgr != null:
		enemy_mgr.refresh_spawners()
	var spawner_count = enemy_mgr.spawners.size() if enemy_mgr != null else 0
	check.call("EnemyManager registered all 5 spawners", spawner_count == 5, "Found: " + str(spawner_count))

	print("\n==================================================")
	print("RESULTS: " + str(stats[0]) + " / " + str(stats[1]) + " checks passed.")
	print("==================================================")

	if stats[0] == stats[1]:
		print("SUCCESS: Scene hierarchy refactoring 100% verified!")
		quit(0)
	else:
		printerr("FAILURE: " + str(stats[1] - stats[0]) + " checks failed.")
		quit(1)
