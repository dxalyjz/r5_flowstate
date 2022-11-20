global function MpWeaponEmoteProjector_Init

global function OnWeaponTossReleaseAnimEvent_WeaponEmoteProjector
global function OnWeaponAttemptOffhandSwitch_WeaponEmoteProjector
global function OnWeaponTossPrep_WeaponEmoteProjector
global function OnProjectileCollision_holospray

#if CLIENT
global function HoloSpray_OnUse
global function GetEmotesTable
#endif

global const int HOLO_PROJECTOR_INDEX = 6

const asset LIGHT_PARTICLE_TEST = $"P_BT_eye_proj_holo"
const asset TEST_MODEL = $"mdl/fx/ar_holopulse.rmdl"

const vector EMOTE_ICON_TEXT_OFFSET = <0,0,60>

const float HOLO_EMOTE_LIFETIME = 999.0
const string SOUND_HOLOGRAM_LOOP = "Survival_Emit_RespawnChamber"

global const asset HOLO_SPRAY_BASE = $"mdl/props/holo_spray/holo_spray_base.rmdl"

struct
{
	#if SERVER
	
	#endif
	#if CLIENT
		table<int, array<asset> > emotes = {}
	#endif

} file

void function MpWeaponEmoteProjector_Init()
{
	#if CLIENT || SERVER
		PrecacheModel(TEST_MODEL)
		PrecacheModel( HOLO_SPRAY_BASE )
	#endif

	#if CLIENT
		var dataTable = GetDataTable( $"datatable/emotescustom.rpak" )
		
		for ( int i = 0; i < GetDatatableRowCount( dataTable ); i++ )
		{
			int id = GetDataTableInt( dataTable, i, GetDataTableColumnByName( dataTable, "id" ) )
			string emote = GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "asset" ) )
			if(id in file.emotes)
				file.emotes[id].append(CastStringToAsset(emote))
			else
				file.emotes[id] <- [CastStringToAsset(emote)]
			
		}
		
		PrecacheParticleSystem(LIGHT_PARTICLE_TEST)
	#endif
	
	#if SERVER
		AddClientCommandCallback( "HoloSpray_OnUse", ClientCommand_HoloSpray_OnUse )
	#endif

}

#if CLIENT
table<int, array<asset> > function GetEmotesTable()
{
	return file.emotes
}
#endif

void function OnProjectileCollision_holospray( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	if( !IsValid(projectile) ) return
	entity player = projectile.GetOwner()
	
	if ( IsValid(hitEnt) && hitEnt.IsPlayer() )
		return
	
	table collisionParams =
	{
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	
	bool result = PlantStickyEntityOnWorldThatBouncesOffWalls( projectile, collisionParams, 0.7 )
	
	if(result && IsValid(projectile))
	{
		vector GoodAngles = AnglesOnSurface(normal, -AnglesToRight(player.EyeAngles()))	
		vector origin = projectile.GetOrigin()

		#if SERVER
		entity prop = CreatePropDynamic(HOLO_SPRAY_BASE, origin, GoodAngles, 6, -1)
		// EmitSoundOnEntity(prop, "weapon_sentryfragdrone_pinpull_3p")
		foreach ( sPlayer in GetPlayerArray() )
			Remote_CallFunction_NonReplay( sPlayer, "HoloSpray_OnUse", prop, player.p.holosprayChoice)
		// prop.Anim_PlayOnly("animseq/props/holo_spray/holo_spray_open_idle.rseq")
		projectile.Destroy()
		#endif
	}
}

bool function OnWeaponAttemptOffhandSwitch_WeaponEmoteProjector( entity weapon )
{
	return true
}

var function OnWeaponTossReleaseAnimEvent_WeaponEmoteProjector( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
	if ( !weapon.ShouldPredictProjectiles() )
		return 0
	#endif

	int ammoReq = weapon.GetAmmoPerShot()
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )
	
	entity player = weapon.GetWeaponOwner()
	int damageFlags = weapon.GetWeaponDamageFlags()
	WeaponFireBoltParams fireBoltParams
	fireBoltParams.pos = attackParams.pos
	fireBoltParams.dir = attackParams.dir
	fireBoltParams.speed = 500
	fireBoltParams.scriptTouchDamageType = damageFlags
	fireBoltParams.scriptExplosionDamageType = damageFlags
	fireBoltParams.clientPredicted = false
	fireBoltParams.additionalRandomSeed = 0
	entity bullet = weapon.FireWeaponBoltAndReturnEntity( fireBoltParams )

	return ammoReq
}

void function OnWeaponTossPrep_WeaponEmoteProjector( entity weapon, WeaponTossPrepParams prepParams )
{
	weapon.EmitWeaponSound_1p3p( GetGrenadeDeploySound_1p( weapon ), GetGrenadeDeploySound_3p( weapon ) )
}

#if CLIENT
void function MoverCleanup( entity wp, entity mover )
{
	wp.EndSignal( "OnDestroy" )
	mover.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( mover) {
			if ( IsValid( mover ) )
				mover.Destroy()
		}
	)

	while ( IsValid( wp ) )
		wait 0.1
}

void function HoloSpray_OnUse(entity prop, int choice)
{
	vector origin = prop.GetOrigin()
	vector angles =  VectorToAngles( prop.GetOrigin() - GetLocalClientPlayer().GetOrigin() )
	float width = 40
	float height = 40
	
	origin += (AnglesToUp( angles )*-1) * (height*0.5)  // instead of pinning from center, pin from top center
	origin.z += 110
	
	var topo = CreateRUITopology_Worldspace( origin, Vector(0,angles.y,0), width, height )
	var rui = RuiCreate( $"ui/basic_image.rpak", topo, RUI_DRAW_WORLD, 32767 )
	
	RuiSetFloat(rui, "basicImageAlpha", 0.8)
	
	thread EmotePlayAsset(rui, choice)
	
	// GetDatatableRowCount
	// GetDataTableColumnByName( dataTable, "name" )
	// GetDataTableString( dataTable, i, GetDataTableColumnByName( dataTable, "name" ) )
	// GetDataTableInt( passDataTable, numRows - 1, GetDataTableColumnByName( passDataTable, "levelIndex" ) ) + 1
	// GetDataTableAsset( datatable, rowIndex, GetDataTableColumnByName( datatable, columnName ) )
	// GetDataTableBool( datatable, rowIndex, GetDataTableColumnByName( datatable, columnName ) )
	// GetDataTableFloat( datatable, rowIndex, GetDataTableColumnByName( datatable, columnName ) )
	// int row = GetDataTableRowMatchingStringValue( attachmentTable, GetDataTableColumnByName( attachmentTable, "mod" ), data.ref )

	var fx = StartParticleEffectInWorld( GetParticleSystemIndex( LIGHT_PARTICLE_TEST ), prop.GetOrigin(), Vector(-90,0,0) )
	thread EmoteSetAngles(topo, origin)
}

void function EmotePlayAsset(var rui, int index)
{
	array<asset> assetsToPlay = file.emotes[index]
	
	if(assetsToPlay.len() == 1) //is static
	{
		RuiSetImage( rui, "basicImage", assetsToPlay[0])
	}
	else if(assetsToPlay.len() > 1) //is gif?
		thread PlayAnimatedEmote(rui, assetsToPlay)
}

void function PlayAnimatedEmote(var rui, array<asset> assetsToPlay)
{
	while(true)
	{
		foreach(Asset in assetsToPlay)
		{
			RuiSetImage( rui, "basicImage", Asset)
			wait 0.05
		}
		WaitFrame()
	}
}

void function EmoteSetAngles(var topo, vector origin)
{
	vector angles
	
	while(true)
	{
		entity player = GetLocalViewPlayer()
		vector camPos = player.CameraPosition()
		vector camAng = player.CameraAngles()
		vector closestPoint    = GetClosestPointOnLine( camPos, camPos + (AnglesToRight( camAng ) * 100.0), origin )		
		angles = VectorToAngles( origin - closestPoint )
		
		if (  player.GetAdsFraction() > 0.99 )
		{
			UpdateOrientedTopologyPos(topo, origin, Vector( 90 * ( player.GetAdsFraction() - 0.1), angles.y, 0), 60, 60)
		}
		else
		{
			UpdateOrientedTopologyPos(topo, origin, Vector(0,angles.y,0), 60, 60)
		}
		WaitFrame()
	}
}
#endif

#if SERVER

bool function ClientCommand_HoloSpray_OnUse( entity player, array<string> args )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return true

	if ( args.len() < 1 )
		return true

	player.p.holosprayChoice = int( args[0] )

	return true
}

#endif