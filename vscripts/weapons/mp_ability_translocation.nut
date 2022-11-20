//By @CaféFPS based on retail client script
untyped

global function Translocation_Init
global function OnProjectileIgnite_Translocation
global function OnWeaponTossRelease_Translocation
global function OnWeaponAttemptOffhandSwitch_Translocation
global function OnWeaponActivate_Translocation
global function OnWeaponDeactivate_Translocation
global function OnWeaponTossPrep_Translocation

const asset TRANSLOCATION_WARP_SCREEN_FX = $"P_ability_warp_screen"
const asset TRANSLOCATION_WARP_BEAM_FX = $"P_ability_warp_travel"
const asset TRANSLOCATION_WARP_WORLD_FX = $"P_warp_imp_default"

void function Translocation_Init()
{
	PrecacheParticleSystem( TRANSLOCATION_WARP_SCREEN_FX )
	PrecacheParticleSystem( TRANSLOCATION_WARP_BEAM_FX )
	PrecacheParticleSystem( TRANSLOCATION_WARP_WORLD_FX )
		
	PrecacheParticleSystem( $"P_ar_holopilot_trail" )
	
	RegisterNetworkedVariable( "Translocation_ActiveProjectile", SNDC_PLAYER_EXCLUSIVE, SNVT_ENTITY )
	RegisterSignal("Translocation_Deactivate")
	RegisterSignal("CancelAnimationThread")
}

void function OnWeaponActivate_Translocation( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	Assert( IsValid( owner ) )

	#if SERVER
		                                             
		                                                
		                                                 
		                                                   
		                                                     
	#elseif CLIENT
		if ( !(InPrediction() && IsFirstTimePredicted()) )
			return

		weapon.w.translocate_predictedInitialProjectile = null
		weapon.w.translocate_predictedRedirectedProjectile = null
		weapon.w.translocate_impactRumbleObj = null
	#endif

	thread TranslocationLifetimeThread( owner, weapon )
}

void function TranslocationLifetimeThread( entity owner, entity weapon )
{
	EndSignal( owner, "OnDeath" )
	EndSignal( weapon, "OnDestroy" )
	EndSignal( weapon, "Translocation_Deactivate" )

	string ownerName = IsValid( owner ) ? owner.GetPlayerName() : "NULL"

	bool[1] haveLockedForToss = [false]

	OnThreadEnd( void function() : ( owner, weapon, haveLockedForToss, ownerName ) {

		if ( IsValid( weapon ) )
		{
			if ( weapon.w.translocate_isADSForced )
			{
				#if CLIENT
				if ( InPrediction() )
				#endif
				{
					weapon.ClearForcedADS()
					weapon.w.translocate_isADSForced = false
				}
			}
		}
		if ( IsValid( owner ) )
		{
			if ( haveLockedForToss[0] )
			{
				#if SERVER

				#endif
			}
		}
	} )

	#if CLIENT
	if ( InPrediction() )
	#endif
	{
		weapon.w.translocate_isADSForced = true
		weapon.SetForcedADS()
	}

	int offhandSlot = 0 //!FIXME should 1 if it's in ultimate slot?

	while ( true )
	{
		entity currentActiveOffhandWeapon = owner.GetActiveWeapon( offhandSlot )
		if ( currentActiveOffhandWeapon != weapon )
			break

		#if CLIENT
			// int crosshairStage = eLobaCrosshairStage.HELD
		#endif

		entity currentProjectile = GetCurrentTranslocationProjectile( owner, weapon )
		if ( IsValid( currentProjectile ) )
		{
			#if CLIENT
				// if ( currentProjectile.IsGrenadeStatusFlagSet( GSF_PLANTED ) )
					// crosshairStage = eLobaCrosshairStage.PLANTED
				// else if ( currentProjectile.IsGrenadeStatusFlagSet( GSF_REDIRECTED ) )
					// crosshairStage = eLobaCrosshairStage.REDIRECTED
				// else
					// crosshairStage = eLobaCrosshairStage.TOSSED
			#endif

			if ( !haveLockedForToss[0] )
			{
				#if SERVER
				
				#endif

				haveLockedForToss[0] = true
			}
		}
		else
		{
			#if CLIENT
				// if ( weapon.GetWeaponActivity() == ACT_VM_PICKUP )
					// crosshairStage = eLobaCrosshairStage.TELEPORTED
				// else if ( weapon.GetWeaponActivity() == ACT_VM_MISSCENTER )
					// crosshairStage = eLobaCrosshairStage.FAILED
			#endif
		}
		WaitFrame()
	}
}

void function OnWeaponDeactivate_Translocation( entity weapon )
{
	#if CLIENT
		if ( !InPrediction() )
			return
	#endif

	Signal( weapon, "Translocation_Deactivate" )
}

void function OnWeaponTossPrep_Translocation( entity weapon, WeaponTossPrepParams prepParams )
{
	entity owner = weapon.GetWeaponOwner()

	#if CLIENT
		if ( !(InPrediction() && IsFirstTimePredicted()) )
			return
	#endif

	weapon.EmitWeaponSound_1p3p( GetGrenadeDeploySound_1p( weapon ), GetGrenadeDeploySound_3p( weapon ) )

	// #if CLIENT
		// Rumble_Play( "loba_tactical_pull", {} )
	// #endif
}

bool function OnWeaponAttemptOffhandSwitch_Translocation( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()

	if ( weapon == owner.GetActiveWeapon( eActiveInventorySlot.mainHand ) )
		return false

	if ( !IsPlayerTranslocationPermitted( owner ) )
		return false

	int ammoReq  = weapon.GetAmmoPerShot()
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if ( currAmmo < ammoReq )
		return false

	return true
}

var function OnWeaponTossRelease_Translocation( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// #if SERVER
	// var result = LobaTac_OnWeaponToss( weapon, attackParams, 1.0 )
	// return result
	// #endif
	
	entity owner = weapon.GetWeaponOwner()

	#if SERVER
		  
	#elseif CLIENT
		if ( !(InPrediction() && IsFirstTimePredicted()) )
			return
	#endif

	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	#if SERVER
		                                                             
	#endif

	entity projectile = ThrowDeployable( weapon, attackParams, 1, OnTranslocationProjectilePlanted )
	if ( IsValid( projectile ) )
	{
		PlayerUsedOffhand( owner, weapon, true, projectile )

		#if SERVER
		projectile.e.isDoorBlocker = true
		projectile.e.burnmeter_wasPreviouslyDeployed = weapon.e.burnmeter_wasPreviouslyDeployed

		string projectileSound = GetGrenadeProjectileSound( weapon )
		if ( projectileSound != "" )
			EmitSoundOnEntity( projectile, projectileSound )

		weapon.w.lastProjectileFired = projectile
		projectile.e.burnReward = weapon.e.burnReward
		
		#if BATTLECHATTER_ENABLED
			PlayBattleChatterLineToSpeakerAndTeam( owner, "bc_tactical" )
		#endif
			
		entity fxID = StartParticleEffectOnEntity_ReturnEntity( projectile, GetParticleSystemIndex( $"P_ar_holopilot_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		entity fxID2 = StartParticleEffectOnEntity_ReturnEntity( projectile, GetParticleSystemIndex( $"P_ar_holopilot_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		
		owner.SetPlayerNetEnt( "Translocation_ActiveProjectile", projectile)
		#endif

		#if CLIENT
			weapon.w.translocate_predictedInitialProjectile = projectile
		#endif

		thread TranslocationTossedThread( owner, weapon )
	}

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )    
}

bool function IsPlayerTranslocationPermitted( entity player )
{
	if ( IsValid( player.GetParent() ) && !player.IsPlayerInAnyVehicle() )
		return false

	if ( IsPlayingFirstPersonAnimation( player ) )
		return false

	if ( IsPlayingFirstAndThirdPersonAnimation( player ) )
		return false

	if ( player.IsPhaseShifted() )
		return false

	if ( Bleedout_IsBleedingOut( player ) )
		return false

	bool allowDeployWhileZiplining = true
	bool allowZiplineWhileDeployed = true
	bool isZiplining               = player.ContextAction_IsZipline()

	if ( player.GetWeaponDisableFlags() & WEAPON_DISABLE_FLAGS_MAIN )
	{
		if ( allowZiplineWhileDeployed && isZiplining )
		{
			                                                                          
			                                                                                                                    
		}
		else
		{
			return false
		}
	}

	if ( player.ContextAction_IsActive() )
	{
		if ( (allowDeployWhileZiplining || allowZiplineWhileDeployed) && isZiplining )
		{
			                                                                                                         
			                                                                                            
		}
		else
		{
			return false
		}
	}

	if ( player.ContextAction_IsMeleeExecution() || player.ContextAction_IsMeleeExecutionTarget() )
		return false

	return true
}

#if SERVER
bool function LobaTacCanTeleportHere( entity player, vector testOrg, entity ignoreEnt = null ) //TODO: This is a copy of SP's PlayerPosInSolid(). Not changing it to avoid patching SP. Merge into one function next game
{
	int solidMask = TRACE_MASK_PLAYERSOLID
	vector mins
	vector maxs
	int collisionGroup = TRACE_COLLISION_GROUP_PLAYER
	array<entity> ignoreEnts = [ player ]

	if ( IsValid( ignoreEnt ) )
		ignoreEnts.append( ignoreEnt )
	TraceResults result

	mins = player.GetPlayerMins()
	maxs = player.GetPlayerMaxs()
	result = TraceHull( testOrg, testOrg + < 0, 0, 1 >, mins, maxs, ignoreEnts, solidMask, collisionGroup )

	if ( result.startSolid )
		return false

	return true
}

vector function LobaTacNewPos( entity player, vector testOrg, entity ignoreEnt = null ) //TODO: This is a copy of SP's PlayerPosInSolid(). Not changing it to avoid patching SP. Merge into one function next game
{
	int solidMask = TRACE_MASK_PLAYERSOLID
	vector mins
	vector maxs
	int collisionGroup = TRACE_COLLISION_GROUP_PLAYER
	array<entity> ignoreEnts = [ player ]

	if ( IsValid( ignoreEnt ) )
		ignoreEnts.append( ignoreEnt )
	TraceResults result

	mins = player.GetPlayerMins()
	maxs = player.GetPlayerMaxs()
	result = TraceHull( testOrg, testOrg - <0, 0, 128>, mins, maxs, ignoreEnts, solidMask, collisionGroup )
	//vector fallbackPos = result.endPos
	
	//fallbackPos = fallbackPos - (player.GetViewVector() * (Length( mins )))

	return result.endPos
}
#endif

void function OnProjectileIgnite_Translocation( entity projectile )
{

}

#if CLIENT
void function StartVisualEffect( entity player, int statusEffect, bool actuallyChanged )
{
	if ( player != GetLocalViewPlayer() || (GetLocalViewPlayer() == GetLocalClientPlayer() && !actuallyChanged) )
		return

	thread (void function() : ( player, statusEffect ) {
		EndSignal( player, "OnDeath" )
		EndSignal( player, "Translocation_StopVisualEffect" )

		int fxHandle = StartParticleEffectOnEntityWithPos( player,
			GetParticleSystemIndex( TRANSLOCATION_WARP_SCREEN_FX ),
			FX_PATTACH_ABSORIGIN_FOLLOW, -1, player.EyePosition(), <0, 0, 0> )

		EffectSetIsWithCockpit( fxHandle, true )

		OnThreadEnd( function() : ( fxHandle ) {
			EffectStop( fxHandle, false, true )
		} )

		while( true )
		{
			if ( !EffectDoesExist( fxHandle ) )
				break

			float severity = StatusEffect_GetSeverity( player, statusEffect )
			                                                        
			EffectSetControlPointVector( fxHandle, 1, <severity, 999, 0> )

			WaitFrame()
		}
	})()
}
#endif

entity function GetCurrentTranslocationProjectile( entity owner, entity weapon )
{
	#if SERVER
		if ( !IsValid( owner ) )
			return null
	
		entity serverProjectile = owner.GetPlayerNetEnt( "Translocation_ActiveProjectile" )
			if ( IsValid( serverProjectile ) )
				return serverProjectile
		 
	#endif
	
	#if CLIENT
		if ( IsValid( weapon.w.translocate_predictedRedirectedProjectile ) )
		{
			return weapon.w.translocate_predictedRedirectedProjectile
		}
		else if ( IsValid( weapon.w.translocate_predictedInitialProjectile ) )
		{
			return weapon.w.translocate_predictedInitialProjectile
		}
		else
		{
			entity serverProjectile = owner.GetPlayerNetEnt( "Translocation_ActiveProjectile" )
			if ( IsValid( serverProjectile ) )
				return serverProjectile
		}
	#endif

	return null
}

void function DropToGroundFXThread( entity player, entity existingProjectile, entity predictedRedirectedProjectile, vector currentProjectilePos )
{
	if ( !IsValid( predictedRedirectedProjectile ) || predictedRedirectedProjectile.IsMarkedForDeletion() )
		return

	TraceResults tr = TraceLineHighDetail( currentProjectilePos, currentProjectilePos - <0, 0, 2500>,
		[ existingProjectile, predictedRedirectedProjectile ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE, predictedRedirectedProjectile )

	// FXHandle flashFX = StartEntityFXWithHandle( predictedRedirectedProjectile, TRANSLOCATION_DROP_TO_GROUND_ACTIVATE_FX, FX_PATTACH_ABSORIGIN_FOLLOW, ATTACHMENTID_INVALID )

	// FXHandle lineFX = StartWorldFXWithHandle( TRANSLOCATION_DROP_TO_GROUND_DESTINATION_FX, currentProjectilePos, <0, predictedRedirectedProjectile.GetAngles().y, 0> )
	// #if SERVER
		                         
		                                                                                
	// #endif
	// EffectSetControlPointVector( lineFX, 1, tr.endPos )

	// OnThreadEnd( function () : ( flashFX, lineFX ) {
		// EffectStop( flashFX ) //check server side for EffectStop or just entity destroy COlombia
		// EffectStop( lineFX )
	// } )

	wait 2.0
}

void function OnTranslocationProjectilePlanted( entity projectile )
{
	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) )
		return

	entity weapon = projectile.GetWeaponSource()
	if ( !IsValid( weapon ) )
		return
	vector pos = projectile.GetOrigin()
	#if SERVER
		Assert( IsValid( projectile ) )

		//Do checks + TELEPORT HERE Colombia
		thread ActualTeleport( projectile, projectile.GetOwner(), pos )

	#elseif CLIENT
		// ClientProjectilePlantHandler( weapon, projectile )                   
	#endif
}

#if SERVER
void function ActualTeleport(entity projectile, entity player, vector pos)
{
	entity weapon =  projectile.GetWeaponSource()
	if (LobaTacCanTeleportHere( player, pos, null))
	{
		printl("player teleported")
		ScreenFadeToColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
		player.SetOrigin(pos)
		ScreenFadeFromColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
		EmitSoundOnEntity( player, "Wraith_PhaseGate_Portal_Open")
	}
	else
	{
		vector newpos = pos + <0,0,64>
		if(LobaTacCanTeleportHere( player, newpos, null))
		{
			ScreenFadeToColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
			player.SetOrigin(newpos)
			ScreenFadeFromColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
			EmitSoundOnEntity( player, "Wraith_PhaseGate_Portal_Open")
		}
		else
		{
			newpos = newpos + <0,0,64>
			if(LobaTacCanTeleportHere( player, newpos, null))
			{
				ScreenFadeToColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
				player.SetOrigin(newpos)
				ScreenFadeFromColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
				EmitSoundOnEntity( player, "Wraith_PhaseGate_Portal_Open")
			}
			else
			{
				newpos = newpos + <0,0,64>
				if(LobaTacCanTeleportHere( player, newpos, null))
				{
					ScreenFadeToColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
					player.SetOrigin(newpos)
					ScreenFadeFromColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
					EmitSoundOnEntity( player, "Wraith_PhaseGate_Portal_Open")
				}
				else
				{
					newpos = newpos + <0,0,64>
					if(LobaTacCanTeleportHere( player, newpos, null))
					{
						ScreenFadeToColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
						player.SetOrigin(newpos)
						ScreenFadeFromColor( player, 255.0, 255.0, 255.0, 150.0, 0.3, 0.1 )
						EmitSoundOnEntity( player, "Wraith_PhaseGate_Portal_Open")
					}
					else
					{
						printl("player was in a wall, player was not teleported")
						player.GetOffhandWeapon( OFFHAND_LEFT ).SetWeaponPrimaryClipCount( player.GetOffhandWeapon( OFFHAND_LEFT ).GetWeaponPrimaryClipCountMax() )
					}
				}
			}
		}
	}
	
	thread function() : (weapon)
	{
		Signal(weapon, "CancelAnimationThread")
		weapon.StartCustomActivity( "ACT_VM_PICKUP", WCAF_NONE )
		wait weapon.GetSequenceDuration("animseq/weapons/loba_rings/ptpov_loba_rings/pickup.rseq")
		if(IsValid(weapon))
			weapon.StopCustomActivity()
	}()
	// player.SetArmsModelOverride( $"mdl/Weapons/ptpov_loba_rings/ptpov_loba_rings.rmdl" )
	// entity viewModel = player.GetFirstPersonProxy()
	// viewModel.Anim_Play("animseq/weapons/loba_rings/ptpov_loba_rings/post_toss_01.rseq")
	// PlayAnim( player, "sonar_activate_seq_0" )

	// DeployAndEnableWeapons(player)
    player.UnforceStand()
		
	projectile.Destroy()
	player.SetPlayerNetEnt( "Translocation_ActiveProjectile", null)
}
#endif

void function TranslocationTossedThread( entity owner, entity weapon )
{
	EndSignal( owner, "OnDeath" )
	EndSignal( weapon, "OnDestroy" )
	EndSignal( weapon, "Translocation_Deactivate" )

	array<int> fxIds
	table[1] rumbleHandle = [{}]

	string ownerName = IsValid( owner ) ? owner.GetPlayerName() : "NULL"

	OnThreadEnd( void function() : ( owner, weapon, fxIds, rumbleHandle, ownerName ) {
		#if SERVER
			
		#elseif CLIENT

			// CleanupFXArray( fxIds, true, false )
			// rumbleHandle[0].loop = false
		#endif
	} )

	#if CLIENT
		// rumbleHandle[0] = expect table(Rumble_Play( "loba_tactical_toss_loop", { loop = true, } ))
		                               

		// int dropTargetFXId = -1
		// if ( GetLobaTacticalAllowDropToGround() )
		// {
			// dropTargetFXId = StartParticleEffectInWorldWithHandle( GetParticleSystemIndex( TRANSLOCATION_DROP_TO_GROUND_MARKER_FX ),
				// weapon.GetAttackPosition(), <-90, VectorToAngles( weapon.GetAttackDirection() ).y, 0> )
			// if ( dropTargetFXId != -1 )
				// fxIds.append( dropTargetFXId )
		// }
	#endif

	bool didDrop        = false
	bool dropInProgress = false

	float tossTime     = Time()
	float timeoutDelay = weapon.GetWeaponSettingFloat( eWeaponVar.grenade_fuse_time )
	
	#if SERVER
	thread function() : (owner, weapon)
	{
		EndSignal( owner, "OnDeath" )
		EndSignal( weapon, "OnDestroy" )
		EndSignal( weapon, "Translocation_Deactivate" )
		EndSignal( weapon, "CancelAnimationThread" )
		
		OnThreadEnd( 
			void function() : ( weapon ) 
			{
				printt("exited from anims thread")
			}
		)
		
		entity viewmodel = weapon.GetWeaponViewmodel()
		weapon.StartCustomActivity( "ACT_VM_PICKUP", WCAF_NONE ) //Required to start custom activity mode
		try{ //required
			viewmodel.Anim_NonScriptedPlay("animseq/weapons/loba_rings/ptpov_loba_rings/toss_to_wait.rseq")
	
			}catch(e0){} //required
		wait viewmodel.GetSequenceDuration("animseq/weapons/loba_rings/ptpov_loba_rings/toss_to_wait.rseq")*0.8 //Why - Colombia
		
		if(CoinFlip())
		{
			try{	
				viewmodel.Anim_NonScriptedPlay("animseq/weapons/loba_rings/ptpov_loba_rings/post_toss_01.rseq")			
				}catch(e1){} //required			
			wait viewmodel.GetSequenceDuration("animseq/weapons/loba_rings/ptpov_loba_rings/post_toss_01.rseq")
		}else
		{			
			try{
				viewmodel.Anim_NonScriptedPlay("animseq/weapons/loba_rings/ptpov_loba_rings/post_toss_02.rseq")
			}catch(e2){} //required		
			wait viewmodel.GetSequenceDuration("animseq/weapons/loba_rings/ptpov_loba_rings/post_toss_02.rseq")
		}
		if(IsValid(weapon))
			weapon.StopCustomActivity()
		printt("anim stop")
	}()
	#endif
	
	                               
	                                             
	while( true )
	{
		entity currentProjectile = GetCurrentTranslocationProjectile( owner, weapon )
		if ( !IsValid( currentProjectile ) )
			break
		printt("test")
		#if SERVER
			// entity vm = weapon.GetWeaponViewmodel()
			// // entity viewModel = owner.GetFirstPersonProxy()
			// try{
			// vm.Anim_NonScriptedPlay("animseq/weapons/loba_rings/ptpov_loba_rings/post_toss_02.rseq")
			// }catch(e4201){}
			//maybe force the anim?
		#elseif CLIENT
			// if ( dropTargetFXId != 1 )
				// EffectSetControlPointVector( dropTargetFXId, 0, OriginToGround( currentProjectile.GetOrigin(), TRACE_MASK_NPCWORLDSTATIC, currentProjectile ) + <0, 0, 5> )
		#endif

		                                              
		if ( !IsPlayerTranslocationPermitted( owner ) )
			break

		                                       

		WaitFrame()
	}

	#if SERVER
		                                                           
		 
			                                  
				                                                                                                   
			      
			                                                    
		 
	#endif
}
// bool function OnWeaponRedirectProjectile_ability_translocation( entity weapon, WeaponRedirectParams params )
// {
	// entity owner = weapon.GetWeaponOwner()

	// if ( !GetLobaTacticalAllowDropToGround() )
		// return false

	// float dropToGroundMinimumTime = GetCurrentPlaylistVarFloat( "loba_tactical_drop_minimum_time", 0.24 )
	// if ( Time() < params.projectile.GetProjectileCreationTimeServer() + dropToGroundMinimumTime )
		// return false

	// if ( params.projectile.HasWeaponMod( "redirect_mod" ) )
		// return false

	// #if SERVER
		                                                
			            
	// #endif

	// weapon.StartCustomActivity( "ACT_VM_HITCENTER", WCAF_NONE )

	// WeaponPrimaryAttackParams attackParams
	// attackParams.pos = params.projectilePos
	// attackParams.dir = <0.0, 0.0, -1.0>
	// attackParams.firstTimePredicted = false
	// attackParams.burstIndex = 0
	// attackParams.barrelIndex = 0

	// weapon.AddMod( "redirect_mod" )
	// entity projectile = ThrowDeployable( weapon, attackParams, 1, OnTranslocationProjectilePlanted )
	// weapon.RemoveMod( "redirect_mod" )

	// if ( !IsValid( projectile ) )
		// return false

	// projectile.AddGrenadeStatusFlag( GSF_REDIRECTED )

	// string projectileSound = GetGrenadeProjectileSound( weapon )
	// if ( projectileSound != "" )
		// EmitSoundOnEntity( projectile, projectileSound )

	// #if SERVER
		                                                      
		                                                                            
		                                                                     

		                                                                        

		                                   
		                                                    
		                                                                                                                             

		                                                                                         
		                                                                                      
	// #elseif CLIENT
		// // weapon.w.translocate_predictedRedirectedProjectile = projectile

		// if ( !InPrediction() || IsFirstTimePredicted() )
		// {
			// thread DropToGroundFXThread( owner, projectile, params.projectile, params.projectilePos )
			// EmitSoundOnEntity( projectile, "Loba_TeleportRing_ForceDown_3P" )
		// }
	// #endif

	// return true
// }