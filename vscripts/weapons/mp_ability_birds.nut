//By Colombia
//Arthur Revenge - Bloodhound tactical concept (traps)
//Use it with two players (two instances of the game, so you can se the player being revealed)

// Arthur's revenge
// Play flying animation when someone triggers it
// Take trigger from caustic trap (to avoid tru walls activation)
// Deal damage, reveal enemy and blind him
// Mini steam for attacker (bird's owner)
// Birds can be destroyed if the big one is killed (100 hp)

global function OnProjectileCollision_birds
global function Birds_OnWeaponTossRelease
global function MpBirdsTactical_Init

///CONFIGS///
bool BIRD_TRIGGER_DEBUG = true
float ARTHUR_DAMAGE = 4.0
float BIRDS_RANGE = 150.0
///////////

struct
{
	#if SERVER
	table< entity, int > triggerTargets
	#endif
} file

void function MpBirdsTactical_Init()
{
	PrecacheModel($"mdl/creatures/bird/bird.rmdl")
	PrecacheModel($"mdl/weapons_r5/weapon_tesla_trap/mp_weapon_tesla_trap_ar_trigger_radius.rmdl")
	PrecacheParticleSystem($"dissolve_bird")
	PrecacheParticleSystem($"P_env_ceiling_smoke_dark_256")
}

var function Birds_OnWeaponTossRelease( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if SERVER
	var result = Lift_OnWeaponToss( weapon, attackParams, 1.0 )
	return result
	#endif
}

int function Lift_OnWeaponToss( entity weapon, WeaponPrimaryAttackParams attackParams, float directionScale )
{
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )
	bool projectilePredicted = PROJECTILE_PREDICTED
	bool projectileLagCompensated = PROJECTILE_LAG_COMPENSATED
#if SERVER
	if ( weapon.IsForceReleaseFromServer() )
	{
		projectilePredicted = false
		projectileLagCompensated = false
	}
#endif
	entity grenade = Lift_Launch( weapon, attackParams.pos, (attackParams.dir * directionScale), projectilePredicted, projectileLagCompensated )
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.Signal( "ThrowGrenade" )

	PlayerUsedOffhand( weaponOwner, weapon, true, grenade ) // intentionally here and in Hack_DropGrenadeOnDeath - accurate for when cooldown actually begins

	if ( IsValid( grenade ) )
		grenade.proj.savedDir = weaponOwner.GetViewForward()

#if SERVER
	#if BATTLECHATTER_ENABLED
		TryPlayWeaponBattleChatterLine( weaponOwner, weapon )
	#endif
#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

entity function Lift_Launch( entity weapon, vector attackPos, vector throwVelocity, bool isPredicted, bool isLagCompensated )
{
	//TEMP FIX while Deploy anim is added to sprint
	float currentTime = Time()
	if ( weapon.w.startChargeTime == 0.0 )
		weapon.w.startChargeTime = currentTime

	// Note that fuse time of 0 means the grenade won't explode on its own, instead it depends on OnProjectileCollision() functions to be defined and explode there.
	float fuseTime = weapon.GetGrenadeFuseTime()
	bool startFuseOnLaunch = bool( weapon.GetWeaponInfoFileKeyField( "start_fuse_on_launch" ) )

	if ( fuseTime > 0 && !startFuseOnLaunch )
	{
		fuseTime = fuseTime - ( currentTime - weapon.w.startChargeTime )
		if ( fuseTime <= 0 )
			fuseTime = 0.001
	}

	// NOTE: DO NOT apply randomness to angularVelocity, it messes up lag compensation
	// KNOWN ISSUE: angularVelocity is applied relative to the world, so currently the projectile spins differently based on facing angle
	vector angularVelocity = <10, -1600, 10>

	int damageFlags = weapon.GetWeaponDamageFlags()
	WeaponFireGrenadeParams fireGrenadeParams
	fireGrenadeParams.pos = attackPos
	fireGrenadeParams.vel = throwVelocity
	fireGrenadeParams.angVel = angularVelocity
	fireGrenadeParams.fuseTime = fuseTime
	fireGrenadeParams.scriptTouchDamageType = (damageFlags & ~DF_EXPLOSION) // when a grenade "bonks" something, that shouldn't count as explosive.explosive
	fireGrenadeParams.scriptExplosionDamageType = damageFlags
	fireGrenadeParams.clientPredicted = isPredicted
	fireGrenadeParams.lagCompensated = isLagCompensated
	fireGrenadeParams.useScriptOnDamage = true
	entity frag = weapon.FireWeaponGrenade( fireGrenadeParams )
	if ( frag == null )
		return null

	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		if ( IsValid( owner ) )
		{
			if ( IsWeaponOffhand( weapon ) )
			{
				AddToUltimateRealm( owner, frag )
			}
			else
			{
				frag.RemoveFromAllRealms()
				frag.AddToOtherEntitysRealms( owner )
			}
		}

		//HolsterAndDisableWeapons( owner )
        //owner.ForceStand()
	#endif

	Lift_OnPlayerNPCTossGrenade_Common( weapon, frag )

	return frag
}

void function Lift_OnPlayerNPCTossGrenade_Common( entity weapon, entity frag )
{
	LiftThrow_Init( frag, weapon )
	#if SERVER
		thread TrapExplodeOnDamage( frag, 20, 0.0, 0.0 )
		
		string projectileSound = GetGrenadeProjectileSound( weapon )
		if ( projectileSound != "" )
			EmitSoundOnEntity( frag, projectileSound )

		entity fxID = StartParticleEffectOnEntity_ReturnEntity( frag, GetParticleSystemIndex( $"P_ar_holopilot_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		entity fxID2 = StartParticleEffectOnEntity_ReturnEntity( frag, GetParticleSystemIndex( $"P_ar_holopilot_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )

	#endif
}

void function LiftThrow_Init( entity grenade, entity weapon )
{
	entity weaponOwner = weapon.GetOwner()
	if ( IsValid( weaponOwner ) )
		SetTeam( grenade, weaponOwner.GetTeam() )
	
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) && owner.IsNPC() )
		SetTeam( grenade, owner.GetTeam() )

	#if SERVER
		bool smartPistolVisible = weapon.GetWeaponSettingBool( eWeaponVar.projectile_visible_to_smart_ammo )
		if ( smartPistolVisible )
		{
			grenade.SetDamageNotifications( true )
			grenade.SetTakeDamageType( DAMAGE_EVENTS_ONLY )
			grenade.proj.onlyAllowSmartPistolDamage = true

			if ( !grenade.GetProjectileWeaponSettingBool( eWeaponVar.projectile_damages_owner ) && !grenade.GetProjectileWeaponSettingBool( eWeaponVar.explosion_damages_owner ) )
				SetCustomSmartAmmoTarget( grenade, true ) // prevent friendly target lockon
		}
		else
		{
			grenade.SetTakeDamageType( DAMAGE_NO )
		}
	#endif
		
}

void function OnProjectileCollision_birds( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	entity player = projectile.GetOwner()
	if ( hitEnt == player )
		return

	if ( projectile.GrenadeHasIgnited() )
		return

	table collisionParams =
	{
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	bool result = PlantStickyEntityOnWorldThatBouncesOffWalls( projectile, collisionParams, 0.7 )

	#if SERVER
	projectile.proj.projectileBounceCount++
	if ( !result && projectile.proj.projectileBounceCount < 10 )
	{
		return
	}
	else if ( IsValid( hitEnt ) && ( hitEnt.IsPlayer() || hitEnt.IsTitan() || hitEnt.IsNPC() ) )
	{
		CreateBird_weapon_birds(projectile)
		projectile.Destroy()
	}
	else
	{
		CreateBird_weapon_birds(projectile)
		projectile.Destroy()
	}
	#endif
}
#if SERVER

void function CreateBirdTriggerArea( entity bird, entity player )
{
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
	vector origin = bird.GetOrigin()
	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetOwner( bird )
	trigger.SetRadius( BIRDS_RANGE )
	trigger.SetAboveHeight( BIRDS_RANGE/2 )
	trigger.SetBelowHeight( BIRDS_RANGE/2 )
	trigger.SetOrigin( origin )
	SetTeam( trigger, player.GetTeam() )
	trigger.kv.triggerFilterNonCharacter = "0"
	trigger.RemoveFromAllRealms()
	trigger.AddToOtherEntitysRealms( bird )
	DispatchSpawn( trigger )
	file.triggerTargets[ trigger ] <- 0
	trigger.SetEnterCallback( OnBirdAreaEnter )
	trigger.SetOrigin( origin )
	trigger.SetParent( bird, "", true, 0.0 )
	printt("Trigger created")
}

void function OnBirdAreaEnter( entity trigger, entity ent )
{
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
		thread BirdsProximityActivationUpdate( trigger, ent)
}

void function BirdsProximityActivationUpdate( entity trigger, entity player)
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
{
	Assert ( IsNewThread(), "Must be threaded off." )

	vector offsetOrigin = trigger.GetOrigin() + <0,0,48>

	float maxDist		= 140.0
	int traceMask 		= TRACE_MASK_PLAYERSOLID
	int visConeFlags	= VIS_CONE_ENTS_TEST_HITBOXES | VIS_CONE_RETURN_HIT_VORTEX
	entity antilagPlayer = null

	int team = trigger.GetTeam()

	//printt( "STARTING UPDATE FOR BIRD TRIGGER IN A CONE" )
	entity bird = trigger.GetParent()
	array<entity> touchingEnts = trigger.GetTouchingEntities()
	
	while( touchingEnts.len() && IsValid(trigger) && IsValid(bird))
	{
		touchingEnts = trigger.GetTouchingEntities()
		array<entity> targetEnts
		array<entity> ignoreEnts = []
		
		if(!BIRD_TRIGGER_DEBUG){
			foreach ( entity touchingEnt in touchingEnts )
			{
				if ( touchingEnt.GetTeam() != team )
					targetEnts.append( touchingEnt )
				else
					ignoreEnts.append( touchingEnt )
			}
		} else {
			foreach ( entity touchingEnt in touchingEnts )
			{
				targetEnts.append( touchingEnt )
			}
		}
		//printt( "TARGETS IN TRIGGER: " + targetEnts.len() )
		//printt( "TARGETS IGNORED IN TRIGGER: " + ignoreEnts.len() )
		//if we are not touching any targets end update.
		file.triggerTargets[ trigger ] = targetEnts.len()
		if ( file.triggerTargets[ trigger ] == 0 )
			return
		// array<entity> gasSources = GetEntArrayByScriptName( "dirty_bomb" )
		// ignoreEnts.extend( gasSources )
		// //printt( ignoreEnts.len() )
		foreach ( entity ent in targetEnts )
		{
			//Don't trigger on phase shifted targets.
			if ( ent.IsPhaseShifted() )
				continue

			//Don't trigger on cloaked targets.
			if ( IsCloaked( ent ) )
				continue

			if ( !ent.DoesShareRealms( trigger ) )
				continue

			vector dir = Normalize( ent.GetOrigin() - offsetOrigin )
			array<VisibleEntityInCone> results = FindVisibleEntitiesInCone( offsetOrigin, dir, maxDist, 45, ignoreEnts, traceMask, visConeFlags, antilagPlayer )
			foreach ( result in results )
			{
				if ( !targetEnts.contains( result.ent ) )
					continue

				printt( "TARGET FOUND IN CONE: " + ent )

				trigger.Destroy()
				printt("Trigger destroyed")
				entity mover = CreateScriptMover( bird.GetOrigin(), bird.GetAngles() )
				bird.SetParent( mover, "ref", false, 0.0 )
				
				float animduration1 = bird.GetSequenceDuration( "Bird_react_fly_small"  )
				float animduration2 = bird.GetSequenceDuration( "Bird_eating_idle" )
				
				mover.SetAngles(ent.GetAngles()*-1)
				
				thread PlayAnim( bird, "Bird_react_fly_small", mover, "ref")
				
				foreach (littlebirds in bird.e.birdsFromThisCluster)
				{
					if(IsValid(littlebirds))
					littlebirds.Dissolve( ENTITY_DISSOLVE_BIRD, <0,0,0>, 200 )
					
					#if CLIENT
					int fxId = GetParticleSystemIndex( $"dissolve_bird" )
					int fxHandle = StartParticleEffectOnEntity( littlebirds, fxId, FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
					#endif
				}
				
				mover.NonPhysicsMoveTo(ent.GetOrigin(), 1, 0, 0 )
				wait 1			
					//Status effects for players
					//1. Cool effects for blinding
				StatusEffect_AddTimed( ent, eStatusEffect.smokescreen, 0.5, 2, 1 )
				StatusEffect_AddTimed( ent, eStatusEffect.shellshock, 1 , 2, 1 )
				StatusEffect_AddTimed( ent, eStatusEffect.move_slow, 0.2, 1, 1 ) 
					//2. player is revealed for 2 seconds??
				StatusEffect_AddTimed( ent, eStatusEffect.sonar_detected, 1 , 2, 1 )
				thread TimedCustomHighlight(player, ent)
					//3. player take damage
				thread playertakingdamageovertime(ent, bird)
					//4. Owner gets buffed for 1 second
				StatusEffect_AddTimed( player, eStatusEffect.anti_slow, 0.5, 1.1, 1 )
				StatusEffect_AddTimed( player, eStatusEffect.speed_boost, 1.2, 1.1, 1 )
				StatusEffect_AddTimed( player, eStatusEffect.stim_visual_effect, 1.0, 1, 1 )
				
				bird.Anim_Stop()
				thread FlyingArthurStaticAnimation(bird)
				thread arthurOnCamera(ent, bird, mover)
				wait 1
				bird.Dissolve( ENTITY_DISSOLVE_BIRD, <0,0,0>, 200 )

				#if CLIENT
				int fxId = GetParticleSystemIndex( $"dissolve_bird" )
				int fxHandle = StartParticleEffectOnEntity( bird, fxId, FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
				#endif
				break
			}
		}
		WaitFrame()
	}
}

void function FlyingArthurStaticAnimation(entity flyer)
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
{
	while( IsValid(flyer) )
	{
		if(IsValid(flyer)){
		flyer.Anim_Play( "Bird_react_fly_small" )
		flyer.Anim_SetInitialTime( 0.5 )}
		wait 0.3
		if(IsValid(flyer)) flyer.Anim_Stop()
	}
}

void function playertakingdamageovertime(entity ent, entity bird)
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
{
	while(IsValid(bird)) 
	{
		ent.TakeDamage( ARTHUR_DAMAGE, null, null, { damageSourceId = eDamageSourceId.bubble_shield, damageType = DMG_BURN } )
		wait 0.4
	}
		
}

void function arthurOnCamera(entity ent, entity bird, entity mover)
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
{
	while(IsValid(bird)){
					
				vector tr = ent.GetOrigin() + <0.0, 0.0, 20.0>  + (ent.GetForwardVector() * 15)
				mover.SetOrigin( tr )
				bird.SetAngles(ent.GetAngles()*-1)
				bird.SetOrigin( tr )
				mover.SetAngles( ent.GetAngles() * -1)
				wait 0.0000000000001
	}
}

// void function fadeModelAlphaOutOverTime( entity model, float duration )
// {
	// float startTime = Time()
	// float endTime = startTime + duration
	// int startAlpha = 255
	// int endAlpha = 0

	// model.kv.rendermode = 4 //Rendmode TransAlpha

	// while ( Time() <= endTime )
	// {
		// float alphaResult = GraphCapped( Time(), startTime, endTime, startAlpha, endAlpha )
		// model.kv.renderamt = alphaResult
		// WaitFrame()
	// }
// }

void function CreateBird_weapon_birds( entity projectile )
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
{
	vector origin = projectile.GetOrigin()
	entity owner = projectile.GetThrower()

	if ( !IsValid( owner ) )
		return
	
	int team = owner.GetTeam()
	array<entity> birdsFromThisCluster
	
	entity bird = CreatePropDynamic_NoDispatchSpawn($"mdl/creatures/bird/bird.rmdl", origin, owner.GetAngles()*-1, SOLID_VPHYSICS)
	bird.kv.teamnumber = 99
	bird.kv.fadedist = 5000
	bird.kv.renderamt = 255
	bird.kv.solid = 6
	bird.AllowMantle()
	bird.kv.CollisionGroup = TRACE_COLLISION_GROUP_PLAYER
	bird.kv.rendermode = 3
	bird.kv.rendercolor = "255 255 255 255"
	bird.SetModelScale( 3.5 )
	bird.SetMaxHealth(100)
	bird.SetHealth(100)
	bird.SetDeathNotifications(true)
	DispatchSpawn( bird )
	thread fxOnPlacedBird(bird)
	AddEntityCallback_OnDamaged( bird, Birds_OnDamaged) 
	printt("Creating bird 1")
	
	// entity circle = CreateEntity( "prop_script" )
	// circle.SetValueForModelKey( $"mdl/weapons_r5/weapon_tesla_trap/mp_weapon_tesla_trap_ar_trigger_radius.rmdl" )
	// circle.kv.fadedist = 300
	// circle.kv.renderamt = 0
	// circle.kv.rendercolor = "71, 0, 0"
	// circle.kv.modelscale = 0.45
	// circle.kv.solid = 0
	// circle.SetOrigin( bird.GetOrigin() + <0.0, 0.0, 0>)
	// circle.NotSolid()
	// DispatchSpawn(circle)
	// circle.SetParent(bird)
	
	float r = float(1) / float(5) * 2 * PI
	vector origin2 = origin + 40.0 * <sin( r ), cos( r ), 0.0>
		
	entity bird2 = CreatePropDynamic_NoDispatchSpawn($"mdl/creatures/bird/bird.rmdl", origin2, < 0, RandomFloatRange(-90,90), 0 >, SOLID_VPHYSICS)
	bird2.kv.teamnumber = 99
	bird2.kv.fadedist = 5000
	bird2.kv.renderamt = 255
	bird2.kv.solid = 6
	bird2.AllowMantle()
	bird2.kv.CollisionGroup = TRACE_COLLISION_GROUP_PLAYER
	bird2.kv.rendermode = 3
	bird2.kv.rendercolor = "255 255 255 255"
	bird2.SetModelScale( RandomFloatRange(1.5, 2.5 ) )
	bird2.SetMaxHealth(100)
	bird2.SetHealth(100)
	bird2.SetDeathNotifications(true)
	DispatchSpawn( bird2 )
	birdsFromThisCluster.append(bird2)
	printt("Creating bird2 1")
	
	float r2 = float(2) / float(5) * 2 * PI
	vector origin3 = origin + 40.0 * <sin( r2 ), cos( r2 ), 0.0>
		
	entity bird3 = CreatePropDynamic_NoDispatchSpawn($"mdl/creatures/bird/bird.rmdl", origin3, < 0, RandomFloatRange(-90,90), 0 >, SOLID_VPHYSICS)
	bird3.kv.teamnumber = 99
	bird3.kv.fadedist = 5000
	bird3.kv.renderamt = 255
	bird3.kv.solid = 6
	bird3.AllowMantle()
	bird3.kv.CollisionGroup = TRACE_COLLISION_GROUP_PLAYER
	bird3.kv.rendermode = 3
	bird3.kv.rendercolor = "255 255 255 255"
	bird3.SetModelScale( RandomFloatRange(1.5, 2.5 ) )
	bird3.SetMaxHealth(100)
	bird3.SetHealth(100)
	bird3.SetDeathNotifications(true)
	DispatchSpawn( bird3 )
	birdsFromThisCluster.append(bird3)
	printt("Creating bird2 2")
	
	float r3 = float(3) / float(5) * 2 * PI
	vector origin4 = origin + 40.0 * <sin( r3 ), cos( r3 ), 0.0>
		
	entity bird4 = CreatePropDynamic_NoDispatchSpawn($"mdl/creatures/bird/bird.rmdl", origin4, < 0, RandomFloatRange(-90,90), 0 >, SOLID_VPHYSICS)
	bird4.kv.teamnumber = 99
	bird4.kv.fadedist = 5000
	bird4.kv.renderamt = 255
	bird4.kv.solid = 6
	bird4.AllowMantle()
	bird4.kv.CollisionGroup = TRACE_COLLISION_GROUP_PLAYER
	bird4.kv.rendermode = 3
	bird4.kv.rendercolor = "255 255 255 255"
	bird4.SetModelScale( RandomFloatRange(1.5, 2.5 ) )
	bird4.SetMaxHealth(100)
	bird4.SetHealth(100)
	bird4.SetDeathNotifications(true)
	DispatchSpawn( bird4 )
	birdsFromThisCluster.append(bird4)
	printt("Creating bird2 3")
	
	float r4 = float(4) / float(5) * 2 * PI
	vector origin5 = origin + 40.0 * <sin( r4 ), cos( r4 ), 0.0>
		
	entity bird5 = CreatePropDynamic_NoDispatchSpawn($"mdl/creatures/bird/bird.rmdl", origin5, < 0, RandomFloatRange(-90,90), 0 >, SOLID_VPHYSICS)
	bird5.kv.teamnumber = 99
	bird5.kv.fadedist = 5000
	bird5.kv.renderamt = 255
	bird5.kv.solid = 6
	bird5.AllowMantle()
	bird5.kv.CollisionGroup = TRACE_COLLISION_GROUP_PLAYER
	bird5.kv.rendermode = 3
	bird5.kv.rendercolor = "255 255 255 255"
	bird5.SetModelScale( RandomFloatRange(1.5, 2.5 ) )
	bird5.SetMaxHealth(100)
	bird5.SetHealth(100)
	bird5.SetDeathNotifications(true)
	DispatchSpawn( bird5 )
	birdsFromThisCluster.append(bird5)
	bird5.SetSkin(2)
	printt("Creating bird2 4")
	
	entity mover = CreateScriptMover( bird.GetOrigin(), bird.GetAngles() )
	entity mover2 = CreateScriptMover( bird2.GetOrigin(), bird2.GetAngles() )
	entity mover3 = CreateScriptMover( bird3.GetOrigin(), bird3.GetAngles() )
	entity mover4 = CreateScriptMover( bird4.GetOrigin(), bird4.GetAngles() )
	entity mover5 = CreateScriptMover( bird5.GetOrigin(), bird5.GetAngles() )
				
	bird.SetParent( mover, "ref", false, 0.0 )
	const array<string> BIRD_ANIM_ARRAY = ["Bird_eating_idle","Bird_casual_idle","Bird_cleaning_idle"] //, "Bird_react_fly_small" 
	thread PlayAnim( bird, BIRD_ANIM_ARRAY.getrandom(), mover, "ref")
	thread PlayAnim( bird2, BIRD_ANIM_ARRAY.getrandom(), mover2, "ref")
	thread PlayAnim( bird3, BIRD_ANIM_ARRAY.getrandom(), mover3, "ref")
	thread PlayAnim( bird4, BIRD_ANIM_ARRAY.getrandom(), mover4, "ref")
	thread PlayAnim( bird5, BIRD_ANIM_ARRAY.getrandom(), mover5, "ref")

	bird.e.birdsFromThisCluster = birdsFromThisCluster
	CreateBirdTriggerArea(bird, owner)
}


void function Birds_OnDamaged(entity ent, var damageInfo)
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
///////////////////////////////////////////////////////
{
	entity attacker = DamageInfo_GetAttacker(damageInfo);
	
	if( !IsValid( attacker ) || !attacker.IsPlayer() )
		return
	
	attacker.NotifyDidDamage
	(
		ent,
		DamageInfo_GetHitBox( damageInfo ),
		DamageInfo_GetDamagePosition( damageInfo ), 
		DamageInfo_GetCustomDamageType( damageInfo ),
		DamageInfo_GetDamage( damageInfo ),
		DamageInfo_GetDamageFlags( damageInfo ), 
		DamageInfo_GetHitGroup( damageInfo ),
		DamageInfo_GetWeapon( damageInfo ), 
		DamageInfo_GetDistFromAttackOrigin( damageInfo )
	)

	// Handle damage, props get destroyed on death, we don't want that.
	// Not really needed since it has 1 HP, but we do it anyway.
	float nextHealth = ent.GetHealth() - DamageInfo_GetDamage( damageInfo )
	if( nextHealth > 0 )
	{
		ent.SetHealth(nextHealth)
		return
	}

	// Drone ""died""
	// Don't take damage anymore
	ent.SetTakeDamageType( DAMAGE_NO )
	ent.kv.solid = 0
	
	foreach (littlebirds in ent.e.birdsFromThisCluster)
				{
					if(IsValid(littlebirds))
					littlebirds.Dissolve( ENTITY_DISSOLVE_BIRD, <0,0,0>, 200 )
					#if CLIENT
					int fxId = GetParticleSystemIndex( $"dissolve_bird" )
					int fxHandle = StartParticleEffectOnEntity( littlebirds, fxId, FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
					#endif
				}
	EmitSoundOnEntity( ent, LOOT_DRONE_DEATH_SOUND )
	EmitSoundOnEntity( ent, LOOT_DRONE_CRASHING_SOUND )

	entity effect = StartParticleEffectOnEntity_ReturnEntity
	( 
		ent, 
		GetParticleSystemIndex( LOOT_DRONE_FX_FALL_EXPLOSION ), 
		FX_PATTACH_ABSORIGIN_FOLLOW, 0 
	)
	
		entity trigger = ent.GetParent()
	ent.ClearParent()
	trigger.Destroy()
	ent.SetOwner( attacker )
	ent.kv.teamnumber = attacker.GetTeam()
	ent.Destroy()	
	
	// Kill the particles after a few secs, entity stays in the map indefinitely it seems
	EntFireByHandle( effect, "Kill", "", 2, null, null )
}

void function fxOnPlacedBird(entity bird)
{
	entity fx = PlayLoopFXOnEntity( $"P_env_ceiling_smoke_dark_256", bird, "", < 0, 0, 0 > )
}

void function TimedCustomHighlight(entity player, entity hitEnt, float scanTime = 4)
//Thx pogass
{
    SonarStartGrenade( hitEnt, hitEnt.GetOrigin(), player.GetTeam(), player )
    wait scanTime
    SonarEndGrenadeGrenade( hitEnt, player.GetTeam(), true)
}
#endif