global function MpWeaponPoloSwordPrimary_Init

global function OnWeaponActivate_melee_bolo_sword_primary
global function OnWeaponDeactivate_melee_bolo_sword_primary

const asset SWORD_FX_GLOW = $"P_bFlare_glow_FP"

//P_LL_med_drone_jet_ctr_loop_attk red
//P_LL_med_drone_jet_ctr_loop_attk

void function MpWeaponPoloSwordPrimary_Init()
{
PrecacheParticleSystem($"P_LL_med_drone_jet_ctr_loop_attk")
PrecacheParticleSystem($"P_LL_med_drone_jet_ctr_loop")
PrecacheParticleSystem($"P_xo_exp_nuke_3P")
PrecacheParticleSystem($"P_impact_exp_artillery")

	PrecacheParticleSystem( SWORD_FX_GLOW )
}

void function OnWeaponActivate_melee_bolo_sword_primary( entity weapon )
{
	weapon.PlayWeaponEffect( SWORD_FX_GLOW, $"", "muzzle_flash" )
}

void function OnWeaponDeactivate_melee_bolo_sword_primary( entity weapon )
{
	weapon.StopWeaponEffect( SWORD_FX_GLOW, $"" )
}
