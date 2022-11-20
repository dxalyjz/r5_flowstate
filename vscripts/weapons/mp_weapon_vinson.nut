global function OnWeaponActivate_Vinson
global function OnWeaponDeactivate_Vinson
global function OnWeaponPrimaryAttack_Vinson
global function OnWeaponActivate_RevenantLauncher
global function OnWeaponPrimaryAttack_RevenantLauncher
global function OnProjectileCollision_RevenantLauncher

global function OnProjectileCollision_HealWeapon
global function OnWeaponPrimaryAttack_HealWeapon

#if CLIENT
global function HealWeapon_OnHealTeammate
#endif

void function OnWeaponActivate_Vinson( entity weapon )
{
	OnWeaponActivate_weapon_basic_bolt( weapon )
	#if SERVER
	#endif //
}

void function OnWeaponDeactivate_Vinson( entity weapon )
{
    
}

void function OnProjectileCollision_RevenantLauncher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
	entity hotZoneBeam = StartParticleEffectInWorld_ReturnEntity(GetParticleSystemIndex( $"P_xo_exp_nuke_3P" ), projectile.GetOrigin(), <0,90,0> )

	EmitSoundAtPosition( 99, projectile.GetOrigin(),"weapon_explosion_med" )
	#endif
	
}

var function OnWeaponPrimaryAttack_Vinson( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( weapon.HasMod( "altfire_highcal" ) )
		thread PlayDelayedShellEject( weapon, RandomFloatRange( 0.03, 0.04 ) )

	weapon.FireWeapon_Default( attackParams.pos, attackParams.dir, 1.0, 1.0, false )

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnWeaponActivate_RevenantLauncher( entity weapon )
{
	
	entity vm = weapon.GetWeaponViewmodel()

	try{
	vm.Anim_NonScriptedPlay("animseq/weapons/revenant_grenade/ptpov_revenant_silencer/toss_hold.rseq")
	}catch(e420){}
	
	
	OnWeaponActivate_weapon_basic_bolt( weapon )
	#if SERVER
	#endif //
}

var function OnWeaponPrimaryAttack_RevenantLauncher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if SERVER
	entity vm = weapon.GetWeaponViewmodel()

	try{
	vm.Anim_NonScriptedPlay("animseq/weapons/revenant_grenade/ptpov_revenant_silencer/toss.rseq")
	}catch(e420){}
	thread RevenantLauncherFixAnims(weapon)

	if ( weapon.HasMod( "altfire_highcal" ) )
		thread PlayDelayedShellEject( weapon, RandomFloatRange( 0.03, 0.04 ) )
	
	thread function () : (weapon, attackParams)
	{
		entity player = weapon.GetWeaponOwner()
		int damageFlags = weapon.GetWeaponDamageFlags()
		WeaponFireBoltParams fireBoltParams
		fireBoltParams.pos = attackParams.pos
		fireBoltParams.dir = attackParams.dir
		fireBoltParams.speed = 1
		fireBoltParams.scriptTouchDamageType = damageFlags
		fireBoltParams.scriptExplosionDamageType = damageFlags
		fireBoltParams.clientPredicted = false
		fireBoltParams.additionalRandomSeed = 0
		entity bullet = weapon.FireWeaponBoltAndReturnEntity( fireBoltParams )
		bullet.SetOwner(player)
		bullet.SetModel($"mdl/dev/empty_model.rmdl")
		
		// WaitFrame()
		
		// if(!IsValid(bullet)) return
		// entity fx = StartParticleEffectOnEntity_ReturnEntity(bullet, GetParticleSystemIndex( $"P_dog_w_smoke_trail_SB" ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
		// entity fx2 = StartParticleEffectOnEntity_ReturnEntity(bullet, GetParticleSystemIndex( $"P_LL_med_drone_jet_ctr_loop_attk" ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
		// // WaitFrame()
		// bullet.proj.healWeaponEffects.append(fx)
		// bullet.proj.healWeaponEffects.append(fx2)
		
		// if(!IsValid(player)) return
		// fx.SetAngles(player.GetAngles())
	}()
	
	#endif
	
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

var function OnWeaponPrimaryAttack_HealWeapon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// #if SERVER
	// if ( weapon.HasMod( "altfire_highcal" ) )
		// thread PlayDelayedShellEject( weapon, RandomFloatRange( 0.03, 0.04 ) )
	
	// thread function () : (weapon, attackParams)
	// {
		// entity player = weapon.GetWeaponOwner()
		// int damageFlags = weapon.GetWeaponDamageFlags()
		// WeaponFireBoltParams fireBoltParams
		// fireBoltParams.pos = attackParams.pos
		// fireBoltParams.dir = attackParams.dir
		// fireBoltParams.speed = 1
		// fireBoltParams.scriptTouchDamageType = damageFlags
		// fireBoltParams.scriptExplosionDamageType = damageFlags
		// fireBoltParams.clientPredicted = false
		// fireBoltParams.additionalRandomSeed = 0
		// entity bullet = weapon.FireWeaponBolt( fireBoltParams )
		
		// if(!IsValid(bullet)) return
		
		// bullet.SetOwner(player)
		// bullet.SetModel($"mdl/dev/empty_model.rmdl")
		
		// // WaitFrame()
		
		
		// entity fx = StartParticleEffectOnEntity_ReturnEntity(bullet, GetParticleSystemIndex( $"P_LL_med_drone_jet_ctr_loop" ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
		// entity fx2 = StartParticleEffectOnEntity_ReturnEntity(bullet, GetParticleSystemIndex( $"P_LL_med_drone_jet_ctr_loop_attk" ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
		// // WaitFrame()
		// bullet.proj.healWeaponEffects.append(fx)
		// bullet.proj.healWeaponEffects.append(fx2)
		
		// if(!IsValid(player)) return
		// fx.SetAngles(player.GetAngles())
	// }()
	
	// #endif
	
	// return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnProjectileCollision_HealWeapon( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
	entity player = projectile.GetOwner()
	
	//visuals
	if(!hitEnt.IsPlayer() && !hitEnt.IsNPC()) return
	
	if(hitEnt.GetTeam() != player.GetTeam())
	{
		entity fx = StartParticleEffectOnEntity_ReturnEntity(hitEnt, GetParticleSystemIndex( $"P_LL_med_drone_jet_ctr_loop_attk" ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
		fx.SetOrigin(fx.GetOrigin()+Vector(0,0,50))
		thread DestroyDelayedFx(fx)
	}
	else
	{
		if(IsValid(hitEnt) && hitEnt.GetHealth() < hitEnt.GetMaxHealth())
		{
			hitEnt.SetHealth(min(hitEnt.GetMaxHealth(), hitEnt.GetHealth()+5))
			Remote_CallFunction_NonReplay( player, "HealWeapon_OnHealTeammate", player, hitEnt)
		}
		entity fx = StartParticleEffectOnEntity_ReturnEntity(hitEnt, GetParticleSystemIndex( $"P_LL_med_drone_jet_ctr_loop" ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
		fx.SetOrigin(fx.GetOrigin()+Vector(0,0,50))
		thread DestroyDelayedFx(fx)
	}
	
	#endif
}

#if SERVER
void function DestroyDelayedFx(entity fx)
{
	wait 2
	if(IsValid(fx))
		fx.Destroy()
}
#endif

#if CLIENT
void function HealWeapon_OnHealTeammate(entity attacker, entity victim)
{
	if(!IsValid(attacker) || !IsValid(victim)) return
	
	DamageFlyout( 5, victim.GetOrigin(), victim, eHitType.NORMAL, 0, 0, null, true)
}
#endif

#if SERVER
void function RevenantLauncherFixAnims(entity weapon)
{
	Signal(weapon, "EndFixAnimThread")
	EndSignal(weapon, "EndFixAnimThread")
	wait 0.3
	if(!IsValid(weapon)) return
	entity vm = weapon.GetWeaponViewmodel()
	try{
	vm.Anim_NonScriptedPlay("animseq/weapons/revenant_grenade/ptpov_revenant_silencer/toss_hold.rseq")
	}catch(e420){}
}
#endif