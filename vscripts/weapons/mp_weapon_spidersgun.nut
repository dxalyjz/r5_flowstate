untyped

global function OnProjectileCollision_spidersgun
global function OnProjectileCollision_soldiersgun

global function OnWeaponActivate_spidersgun

void function OnProjectileCollision_spidersgun( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
	entity player = projectile.GetOwner()
	vector GoodAngles = AnglesOnSurface(normal, -AnglesToRight(player.EyeAngles()))

		entity spider = CreateNPC( "npc_spider", 99, pos, GoodAngles )
		SetSpawnOption_AISettings( spider, "npc_spider" )
		DispatchSpawn( spider )
		
		vector ornull clampedPos = NavMesh_ClampPointForAIWithExtents( pos, spider, < 20, 20, 36 > )
		if ( clampedPos != null )
		{
			expect vector( clampedPos )
			spider.SetOrigin( clampedPos )
		}	
		// entity fx = StartParticleEffectOnEntityWithPos_ReturnEntity( spider, GetParticleSystemIndex( FX_FLYER_GLOW2 ), FX_PATTACH_ABSORIGIN_FOLLOW, spider.LookupAttachment( "CHESTFOCUS" ), <0,0,0>, VectorToAngles( <0,0,-1> ) )
		// fx.kv.rendermode = 4
		// fx.kv.renderamt = 100

	#endif
}

void function OnProjectileCollision_soldiersgun( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
	entity player = projectile.GetOwner()
	vector GoodAngles = AnglesOnSurface(normal, -AnglesToRight(player.EyeAngles()))

		entity spider = CreateNPC( "npc_soldier", 99, pos, GoodAngles )
		SetSpawnOption_AISettings( spider, "npc_soldier_infected" )
		DispatchSpawn( spider )
		
		vector ornull clampedPos = NavMesh_ClampPointForAIWithExtents( pos, spider, < 20, 20, 36 > )
		if ( clampedPos != null )
		{
			expect vector( clampedPos )
			spider.SetOrigin( clampedPos )
		}	
		// entity fx = StartParticleEffectOnEntityWithPos_ReturnEntity( spider, GetParticleSystemIndex( FX_FLYER_GLOW2 ), FX_PATTACH_ABSORIGIN_FOLLOW, spider.LookupAttachment( "CHESTFOCUS" ), <0,0,0>, VectorToAngles( <0,0,-1> ) )
		// fx.kv.rendermode = 4
		// fx.kv.renderamt = 100

	#endif
}

void function OnWeaponActivate_spidersgun(entity weapon)
{
	
	
}

