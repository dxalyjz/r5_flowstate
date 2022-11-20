global function Cl_CustomTDM_Init
global function Cl_RegisterLocation
global function OpenTDMWeaponSelectorUI
global function ServerCallback_SendScoreboardToClient
global function ServerCallback_ClearScoreboardOnClient

//Statistics
global function ServerCallback_OpenStatisticsUI

// Voting
global function ServerCallback_FSDM_OpenVotingPhase
global function ServerCallback_FSDM_ChampionScreenHandle
global function ServerCallback_FSDM_UpdateVotingMaps
global function ServerCallback_FSDM_UpdateMapVotesClient
global function ServerCallback_FSDM_SetScreen
global function ServerCallback_FSDM_CoolCamera

//Ui callbacks
global function UI_To_Client_VoteForMap_FSDM

const string CIRCLE_CLOSING_IN_SOUND = "UI_InGame_RingMoveWarning" //"survival_circle_close_alarm_01"

struct CameraLocationPair
{
    vector origin = <0, 0, 0>
    vector angles = <0, 0, 0>
}

struct {
    LocationSettings &selectedLocation
    array<LocationSettings> locationSettings
	int teamwon
	vector victorySequencePosition = < 0, 0, 10000 >
	vector victorySequenceAngles = < 0, 0, 0 >
	SquadSummaryData winnerSquadSummaryData
	bool forceShowSelectedLocation = false
} file

struct VictoryCameraPackage
{
	vector camera_offset_start
	vector camera_offset_end
	vector camera_focus_offset
	float camera_fov
}

bool hasvoted = false
bool isvoting = false
bool roundover = false
array<var> overHeadRuis
array<entity> cleanupEnts

void function Cl_CustomTDM_Init()
{
    AddCallback_EntitiesDidLoad( NotifyRingTimer )
	RegisterButtonPressedCallback(KEY_ENTER, ClientReportChat)
	PrecacheParticleSystem($"P_wpn_lasercannon_aim_short_blue")
	
	RegisterSignal("ChallengeStartRemoveCameras")
	RegisterSignal("ChangeCameraToSelectedLocation")
}

void function Cl_RegisterLocation(LocationSettings locationSettings)
{
    file.locationSettings.append(locationSettings)
}

void function ClientReportChat(var button)
{
	if(CHAT_TEXT  == "") return
	
	string text = "say " + CHAT_TEXT
	GetLocalClientPlayer().ClientCommand(text)
}

void function ServerCallback_FSDM_CoolCamera()
{
    thread CoolCamera()
}

CameraLocationPair function NewCameraPair(vector origin, vector angles)
{
    CameraLocationPair locPair
    locPair.origin = origin
    locPair.angles = angles

    return locPair
}

void function CoolCamera()
//based on sal's tdm
{
    entity player = GetLocalClientPlayer()
	player.EndSignal("ChangeCameraToSelectedLocation")
	array<CameraLocationPair> cutsceneSpawns
	
    if(!IsValid(player)) return
	
	if (GetMapName() == "mp_rr_desertlands_64k_x_64k" || GetMapName() == "mp_rr_desertlands_64k_x_64k_nx" || GetMapName() == "mp_rr_desertlands_64k_x_64k_tt")
	{
		cutsceneSpawns.append(NewCameraPair(<10881.2295, 5903.09863, -3176.7959>, <0, -143.321213, 0>)) 
		cutsceneSpawns.append(NewCameraPair(<9586.79199, 24404.5898, -2019.6366>, <0, -52.6216431, 0>)) 
		cutsceneSpawns.append(NewCameraPair(<630.249573, 13375.9219, -2736.71948>, <0, -43.2706299, 0>))
		cutsceneSpawns.append(NewCameraPair(<16346.3076, -34468.9492, -1109.32153>, <0, -44.3879509, 0>))
		cutsceneSpawns.append(NewCameraPair(<1133.25562, -20102.9648, -2488.08252>, <0, -24.9140873, 0>))
	}
	else if(GetMapName() == "mp_rr_canyonlands_staging")
	{
		cutsceneSpawns.append(NewCameraPair(<32645.04,-9575.77,-25911.94>, <7.71,91.67,0.00>)) 
		cutsceneSpawns.append(NewCameraPair(<49180.1055, -6836.14502, -23461.8379>, <0, -55.7723808, 0>)) 
		cutsceneSpawns.append(NewCameraPair(<43552.3203, -1023.86182, -25270.9766>, <0, 20.9528542, 0>))
		cutsceneSpawns.append(NewCameraPair(<30038.0254, -1036.81982, -23369.6035>, <55, -24.2035522, 0>))
	}
	else if(GetMapName() == "mp_rr_canyonlands_mu1" || GetMapName() == "mp_rr_canyonlands_mu1_night" || GetMapName() == "mp_rr_canyonlands_64k_x_64k")
	{
		cutsceneSpawns.append(NewCameraPair(<-7984.68408, -16770.2031, 3972.28271>, <0, -158.605301, 0>)) 
		cutsceneSpawns.append(NewCameraPair(<-19691.1621, 5229.45264, 4238.53125>, <0, -54.6054993, 0>))
		cutsceneSpawns.append(NewCameraPair(<13270.0576, -20413.9023, 2999.29468>, <0, 98.6180649, 0>))
		cutsceneSpawns.append(NewCameraPair(<-25250.0391, -723.554199, 3427.51831>, <0, -55.5126762, 0>))
	}

    //EmitSoundOnEntity( player, "music_skyway_04_smartpistolrun" )

    float playerFOV = player.GetFOV()
	
	cutsceneSpawns.randomize()
	vector randomcameraPos = cutsceneSpawns[0].origin
	vector randomcameraAng = cutsceneSpawns[0].angles
	
    entity camera = CreateClientSidePointCamera(randomcameraPos, randomcameraAng, 17)
    camera.SetFOV(100)
    entity cutsceneMover = CreateClientsideScriptMover($"mdl/dev/empty_model.rmdl", randomcameraPos, randomcameraAng)
    camera.SetParent(cutsceneMover)
	GetLocalClientPlayer().SetMenuCameraEntity( camera )
	DoF_SetFarDepth( 6000, 10000 )	
	
	OnThreadEnd(
		function() : ( player, cutsceneMover, camera, cutsceneSpawns )
		{
			thread function() : (player, cutsceneMover, camera, cutsceneSpawns)
			{
				 
				EndSignal(player, "ChallengeStartRemoveCameras")
				
				OnThreadEnd(
				function() : ( player, cutsceneMover, camera )
				{
					GetLocalClientPlayer().ClearMenuCameraEntity()
					cutsceneMover.Destroy()

					// if(IsValid(player))
					// {
						// FadeOutSoundOnEntity( player, "music_skyway_04_smartpistolrun", 1 )
					// }
					if(IsValid(camera))
					{
						camera.Destroy()
					}
					DoF_SetNearDepthToDefault()
					DoF_SetFarDepthToDefault()			
				})
				
				
				waitthread CoolCameraMovement(player, cutsceneMover, camera, cutsceneSpawns, true)
			}()
		}
	)
	
	waitthread CoolCameraMovement(player, cutsceneMover, camera, cutsceneSpawns)
}

void function CoolCameraMovement(entity player, entity cutsceneMover, entity camera, array<CameraLocationPair> cutsceneSpawns, bool isSelectedZoneCamera = false)
{
	int locationindex = 0
	
	vector moveto
	vector anglesto
	
	if(isSelectedZoneCamera)
	{
		moveto = cutsceneSpawns[locationindex].origin
		anglesto = cutsceneSpawns[locationindex].angles		
	}
	else
	{
		moveto = cutsceneSpawns[locationindex].origin
		anglesto = cutsceneSpawns[locationindex].angles
	}
		
	while(true){
		if(locationindex == cutsceneSpawns.len()){
			locationindex = 0
		}
		
		if(!isSelectedZoneCamera)
		{
			moveto = cutsceneSpawns[locationindex].origin
			anglesto = cutsceneSpawns[locationindex].angles		
		}
		locationindex++
		cutsceneMover.SetOrigin(moveto)
		cutsceneMover.SetAngles(anglesto)
		camera.SetOrigin(moveto)
		camera.SetAngles(anglesto)
		cutsceneMover.NonPhysicsMoveTo(moveto + AnglesToRight(anglesto) * 700, 15, 0, 0)
		
		if(isSelectedZoneCamera) WaitForever()
		else wait 5
	}	
}

void function NotifyRingTimer()
{
    if( GetGlobalNetTime( "nextCircleStartTime" ) < Time() )
        return
    
    UpdateFullmapRuiTracks()

    float new = GetGlobalNetTime( "nextCircleStartTime" )

    var gamestateRui = ClGameState_GetRui()
	array<var> ruis = [gamestateRui]
	var cameraRui = GetCameraCircleStatusRui()
	if ( IsValid( cameraRui ) )
		ruis.append( cameraRui )

	int roundNumber = (SURVIVAL_GetCurrentDeathFieldStage() + 1)
	string roundString = Localize( "#SURVIVAL_CIRCLE_STATUS_ROUND_CLOSING", roundNumber )
	if ( SURVIVAL_IsFinalDeathFieldStage() )
		roundString = Localize( "#SURVIVAL_CIRCLE_STATUS_ROUND_CLOSING_FINAL" )
	DeathFieldStageData data = GetDeathFieldStage( SURVIVAL_GetCurrentDeathFieldStage() )
	float currentRadius      = SURVIVAL_GetDeathFieldCurrentRadius()
	float endRadius          = data.endRadius

	foreach( rui in ruis )
	{
		RuiSetGameTime( rui, "circleStartTime", new )
		RuiSetInt( rui, "roundNumber", roundNumber )
		RuiSetString( rui, "roundClosingString", roundString )

		entity localViewPlayer = GetLocalViewPlayer()
		if ( IsValid( localViewPlayer ) )
		{
			RuiSetFloat( rui, "deathfieldStartRadius", currentRadius )
			RuiSetFloat( rui, "deathfieldEndRadius", endRadius )
			RuiTrackFloat3( rui, "playerOrigin", localViewPlayer, RUI_TRACK_ABSORIGIN_FOLLOW )

			#if(true)
				RuiTrackInt( rui, "teamMemberIndex", localViewPlayer, RUI_TRACK_PLAYER_TEAM_MEMBER_INDEX )
			#endif
		}
	}

    if ( SURVIVAL_IsFinalDeathFieldStage() )
        roundString = "#SURVIVAL_CIRCLE_ROUND_FINAL"
    else
        roundString = Localize( "#SURVIVAL_CIRCLE_ROUND", SURVIVAL_GetCurrentRoundString() )

    float duration = 7.0

    AnnouncementData announcement
    announcement = Announcement_Create( "" )
    Announcement_SetSubText( announcement, roundString )
    Announcement_SetHeaderText( announcement, "#SURVIVAL_CIRCLE_WARNING" )
    Announcement_SetDisplayEndTime( announcement, new )
    Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_CIRCLE_WARNING )
    Announcement_SetSoundAlias( announcement, CIRCLE_CLOSING_IN_SOUND )
    Announcement_SetPurge( announcement, true )
    Announcement_SetPriority( announcement, 200 ) //
    Announcement_SetDuration( announcement, duration )

    AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}

void function OpenTDMWeaponSelectorUI()
{
	entity player = GetLocalClientPlayer()
    player.ClientCommand("CC_TDM_Weapon_Selector_Open")
	DoF_SetFarDepth( 1, 300 )
	RunUIScript("OpenFRChallengesSettingsWpnSelector")
}

void function ServerCallback_SendScoreboardToClient(int eHandle, int score, int deaths, float kd, int damage, int latency)
{
	// for(int i = 1; i < 21; i++ )
	// {} debug
	RunUIScript( "SendScoreboardToUI", EHI_GetName(eHandle), score, deaths, kd, damage, latency)
}

void function ServerCallback_ClearScoreboardOnClient()
{
	RunUIScript( "ClearScoreboardOnUI")
}

void function ServerCallback_OpenStatisticsUI()
{
	entity player = GetLocalClientPlayer()
	RunUIScript( "OpenStatisticsUI" )	
}

void function ServerCallback_FSDM_OpenVotingPhase(bool shouldOpen)
{
	if(shouldOpen)
		RunUIScript( "Open_FSDM_VotingPhase" )	
	else
		thread FSDM_CloseVotingPhase()
	DoF_SetFarDepth( 1, 5000 )
}

void function ServerCallback_FSDM_ChampionScreenHandle(bool shouldOpen, int TeamWon, int skinindex)
{
    file.teamwon = TeamWon
	
    if( shouldOpen )
        thread CreateChampionUI(skinindex)
    else
        thread DestroyChampionUI()
}

void function CreateChampionUI(int skinindex)
{
    hasvoted = false
    isvoting = true
    roundover = true
	
    EmitSoundOnEntity( GetLocalClientPlayer(), "Music_CharacterSelect_Wattson" )
    // ScreenFade(GetLocalClientPlayer(), 0, 0, 0, 255, 0.4, 0.5, FFADE_OUT | FFADE_PURGE)
    // wait 0.9
	
    entity targetBackground = GetEntByScriptName( "target_char_sel_bg_new" )
    entity targetCamera = GetEntByScriptName( "target_char_sel_camera_new" )

    //Clear Winning Squad Data
    AddWinningSquadData( -1, -1)

    //Set Squad Data For Each Player In Winning Team
	foreach( int i, entity player in GetPlayerArrayOfTeam( file.teamwon ) )
    {
		AddWinningSquadData( i, player.GetEncodedEHandle())
    }

    thread Show_FSDM_VictorySequence(skinindex)
	
    // ScreenFade(GetLocalClientPlayer(), 0, 0, 0, 255, 0.3, 0.0, FFADE_IN | FFADE_PURGE)
}

void function DestroyChampionUI()
{
    foreach( rui in overHeadRuis )
		RuiDestroyIfAlive( rui )

    foreach( entity ent in cleanupEnts )
		ent.Destroy()

    overHeadRuis.clear()
    cleanupEnts.clear()	
}

void function FSDM_CloseVotingPhase()
{
    isvoting = false
    
    FadeOutSoundOnEntity( GetLocalClientPlayer(), "Music_CharacterSelect_Event3_Solo", 0.2 )

    wait 1

    GetLocalClientPlayer().ClearMenuCameraEntity()

    RunUIScript( "Close_FSDM_VoteMenu" )
    GetLocalClientPlayer().Signal("ChallengeStartRemoveCameras")

}

void function UpdateUIVoteTimer()
{
    int time = 15
    while(time > -1)
    {
        RunUIScript( "UpdateVoteTimer_FSDM", time)

        if (time <= 5 && time != 0)
            EmitSoundOnEntity( GetLocalClientPlayer(), "ui_ingame_markedfordeath_countdowntomarked" )

        if (time == 0)
            EmitSoundOnEntity( GetLocalClientPlayer(), "ui_ingame_markedfordeath_countdowntoyouaremarked" )

        time--

        wait 1
    }
}

void function UI_To_Client_VoteForMap_FSDM(int mapid)
{
    if(hasvoted)
        return

    entity player = GetLocalClientPlayer()
    player.ClientCommand("VoteForMap " + mapid)
    RunUIScript("UpdateVotedFor_FSDM", mapid + 1)

    hasvoted = true
}

void function ServerCallback_FSDM_UpdateMapVotesClient( int map1votes, int map2votes, int map3votes, int map4votes)
{
    RunUIScript("UpdateVotesUI_FSDM", map1votes, map2votes, map3votes, map4votes)
}

void function ServerCallback_FSDM_UpdateVotingMaps( int map1, int map2, int map3, int map4)
{
    RunUIScript("UpdateMapsForVoting_FSDM", file.locationSettings[map1].name, file.locationSettings[map1].locationAsset, file.locationSettings[map2].name, file.locationSettings[map2].locationAsset, file.locationSettings[map3].name, file.locationSettings[map3].locationAsset, file.locationSettings[map4].name, file.locationSettings[map4].locationAsset)
}

void function ServerCallback_FSDM_SetScreen(int screen, int team, int mapid, int done)
{
    switch(screen)
    {
        case eFSDMScreen.ScoreboardUI: //Sets the screen to the winners screen
			DestroyChampionUI()
            RunUIScript("Set_FSDM_ScoreboardScreen")
            break

        case eFSDMScreen.WinnerScreen: //Sets the screen to the winners screen
            RunUIScript("Set_FSDM_TeamWonScreen", GetWinningTeamText(team))
            break

        case eFSDMScreen.VoteScreen: //Sets the screen to the vote screen
            EmitSoundOnEntity( GetLocalClientPlayer(), "UI_PostGame_CoinMove" )
            thread UpdateUIVoteTimer()
            RunUIScript("Set_FSDM_VotingScreen")
            break

        case eFSDMScreen.TiedScreen: //Sets the screen to the tied screen
            switch(done)
            {
            case 0:
                EmitSoundOnEntity( GetLocalClientPlayer(), "HUD_match_start_timer_tick_1P" )
                break
            case 1:
                EmitSoundOnEntity( GetLocalClientPlayer(),  "UI_PostGame_CoinMove" )
                break
            }

            if (mapid == 42069)
                RunUIScript( "UpdateVotedLocation_FSDMTied", "")
            else
                RunUIScript( "UpdateVotedLocation_FSDMTied", file.locationSettings[mapid].name)
            break

        case eFSDMScreen.SelectedScreen: //Sets the screen to the selected location screen
            EmitSoundOnEntity( GetLocalClientPlayer(), "UI_PostGame_Level_Up_Pilot" )
            RunUIScript( "UpdateVotedLocation_FSDM", file.locationSettings[mapid].name)
			file.selectedLocation = file.locationSettings[mapid]
			Signal(GetLocalClientPlayer(), "ChangeCameraToSelectedLocation")
            break

        case eFSDMScreen.NextRoundScreen: //Sets the screen to the next round screen
            EmitSoundOnEntity( GetLocalClientPlayer(), "UI_PostGame_Level_Up_Pilot" )
            FadeOutSoundOnEntity( GetLocalClientPlayer(), "Music_CharacterSelect_Wattson", 0.2 )
            RunUIScript("Set_FSDM_VoteMenuNextRound")
            break
    }
}

string function GetWinningTeamText(int team)
{
    string teamwon = ""
    // switch(team)
    // {
        // case TEAM_IMC:
            // teamwon = "IMC has won"
            // break
        // case TEAM_MILITIA:
            // teamwon = "MILITIA has won"
            // break
        // case 69:
            // teamwon = "Winner couldn't be decided"
            // break
    // }
	if(IsFFAGame())
		teamwon = GetPlayerArrayOfTeam( team )[0].GetPlayerName() + " has won."
	else
		teamwon = "Team " + team + " has won."
	
    return teamwon
}

array<ItemFlavor> function GetAllGoodAnimsFromGladcardStancesForCharacter_ChampionScreen(ItemFlavor character)
///////////////////////////////////////////////////////
//By Retículo Endoplasmático#5955 (CaféDeColombiaFPS)//
/////////////////////////////////////////////////////// 
//Don't try this at home
{
	array<ItemFlavor> actualGoodAnimsForThisCharacter
	switch(ItemFlavor_GetHumanReadableRef( character )){
			case "character_pathfinder":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00267302733" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00543164026" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01261908739" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00913866781" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01749100240" ) ) )
		return actualGoodAnimsForThisCharacter
		
			case "character_bangalore":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00775529591" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID02041779191" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID02122844468" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01046964932" ) ) )
		return actualGoodAnimsForThisCharacter
		
			case "character_bloodhound":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00982377873" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00091072289" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01817535639" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00921909335" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01299384641" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00924111436" ) ) )
		return actualGoodAnimsForThisCharacter
		
			case "character_caustic":
		if(GetMapName() != "mp_rr_canyonlands_mu1" && GetMapName() != "mp_rr_canyonlands_mu1_night" && GetMapName() != "mp_rr_canyonlands_64k_x_64k") 
		{actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01037940994" ) ) )}
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01924098215" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00844387739" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01590253725" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01450555761" ) ) )
		return actualGoodAnimsForThisCharacter
		
			case "character_gibraltar":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00335495845" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01763092699" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01066049905" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01139949206" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00558533496" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID02081761479" ) ) )
		return actualGoodAnimsForThisCharacter
		
			case "character_lifeline":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00294421454" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00693685311" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00545796048" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00036505096" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01386679009" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01657023826" ) ) )
		return actualGoodAnimsForThisCharacter

			case "character_mirage":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01262193178" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00986179205" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID02083161296" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00859145007" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00563654629" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00002234092" ) ) )
		return actualGoodAnimsForThisCharacter
		
			case "character_octane":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01115114314" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00718158226" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00914410572" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01698467954" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00796629018" ) ) )
		return actualGoodAnimsForThisCharacter
		
			case "character_wraith":
		// actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID02046254916" ) ) )
		// actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01527711638" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01474484292" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01587991597" ) ) )
		//actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID02088801000" ) ) )
		return actualGoodAnimsForThisCharacter

			case "character_wattson":
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01198897745" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01638491567" ) ) )
		if(GetMapName() != "mp_rr_canyonlands_mu1" && GetMapName() != "mp_rr_canyonlands_mu1_night" && GetMapName() != "mp_rr_canyonlands_64k_x_64k") 
		{actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01313080345" ) ) )}
		return actualGoodAnimsForThisCharacter
		
			case "character_crypto":
		if(GetMapName() != "mp_rr_canyonlands_mu1" && GetMapName() != "mp_rr_canyonlands_mu1_night" && GetMapName() != "mp_rr_canyonlands_64k_x_64k") 
		{actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00269538572" ) ) )}
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID00814728196" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01157264561" ) ) )
		actualGoodAnimsForThisCharacter.append( GetItemFlavorByGUID( ConvertItemFlavorGUIDStringToGUID( "SAID01574566414" ) ) )
		return actualGoodAnimsForThisCharacter
	}
	return actualGoodAnimsForThisCharacter
}

//Orginal code from cl_gamemode_survival.nut
//Modifed slightly
void function Show_FSDM_VictorySequence(int skinindex)
{
	entity player = GetLocalClientPlayer()

    //Todo: each maps victory pos and ang
    file.victorySequencePosition = file.selectedLocation.victorypos.origin - < 0, 0, 52>
	file.victorySequenceAngles = file.selectedLocation.victorypos.angles

	asset defaultModel                = GetGlobalSettingsAsset( DEFAULT_PILOT_SETTINGS, "bodyModel" )
	LoadoutEntry loadoutSlotCharacter = Loadout_CharacterClass()
	vector characterAngles            = < file.victorySequenceAngles.x / 2.0, file.victorySequenceAngles.y, file.victorySequenceAngles.z >

	VictoryPlatformModelData victoryPlatformModelData = GetVictorySequencePlatformModel()
	entity platformModel

	int maxPlayersToShow = 9

	if ( victoryPlatformModelData.isSet )
	{
		platformModel = CreateClientSidePropDynamic( file.victorySequencePosition + victoryPlatformModelData.originOffset, victoryPlatformModelData.modelAngles, victoryPlatformModelData.modelAsset )

		cleanupEnts.append( platformModel )
		int playersOnPodium = 0

		VictorySequenceOrderPlayerFirst( player )

		foreach( int i, SquadSummaryPlayerData data in file.winnerSquadSummaryData.playerData )
		{
			if ( maxPlayersToShow > 0 && i > maxPlayersToShow )
				break

			string playerName = ""
			if ( EHIHasValidScriptStruct( data.eHandle ) )
				playerName = EHI_GetName( data.eHandle )

			if ( !LoadoutSlot_IsReady( data.eHandle, loadoutSlotCharacter ) )
				continue

			ItemFlavor character = LoadoutSlot_GetItemFlavor( data.eHandle, loadoutSlotCharacter )

			if ( !LoadoutSlot_IsReady( data.eHandle, Loadout_CharacterSkin( character ) ) )
				continue

			ItemFlavor characterSkin = GetValidItemFlavorsForLoadoutSlot( data.eHandle, Loadout_CharacterSkin( character ) )[GetValidItemFlavorsForLoadoutSlot( data.eHandle, Loadout_CharacterSkin( character ) ).len()-skinindex]
			
			vector pos = GetVictorySquadFormationPosition( file.victorySequencePosition, file.victorySequenceAngles, i )
			entity characterNode = CreateScriptRef( pos, characterAngles )
			characterNode.SetParent( platformModel, "", true )

			entity characterModel = CreateClientSidePropDynamic( pos, characterAngles, defaultModel )
			SetForceDrawWhileParented( characterModel, true )
			characterModel.MakeSafeForUIScriptHack()
			CharacterSkin_Apply( characterModel, characterSkin )

			cleanupEnts.append( characterModel )

			foreach( func in s_callbacks_OnVictoryCharacterModelSpawned )
				func( characterModel, character, data.eHandle )

			characterModel.SetParent( characterNode, "", false )
			ItemFlavor anim = GetAllGoodAnimsFromGladcardStancesForCharacter_ChampionScreen(character).getrandom()
			asset animtoplay = GetGlobalSettingsAsset( ItemFlavor_GetAsset( anim ), "movingAnimSeq" )
			
			thread PlayAnim( characterModel, animtoplay, characterNode )
			characterModel.Anim_SetPlaybackRate(0.8)
			
			characterModel.Anim_EnableUseAnimatedRefAttachmentInsteadOfRootMotion()

			entity overheadNameEnt = CreateClientSidePropDynamic( pos + (AnglesToUp( file.victorySequenceAngles ) * 73), <0, 0, 0>, $"mdl/dev/empty_model.rmdl" )
			overheadNameEnt.Hide()

			var overheadRuiName = RuiCreate( $"ui/winning_squad_member_overhead_name.rpak", clGlobal.topoFullScreen, RUI_DRAW_HUD, 0 )
			RuiSetString(overheadRuiName, "playerName", playerName)
			RuiTrackFloat3(overheadRuiName, "position", overheadNameEnt, RUI_TRACK_ABSORIGIN_FOLLOW)

			overHeadRuis.append( overheadRuiName )

			playersOnPodium++
		}

		string dialogueApexChampion
        // if (file.teamwon == TEAM_IMC || file.teamwon == TEAM_MILITIA)
        // {
            if (player.GetTeam() == file.teamwon)
            {
                if ( playersOnPodium > 1 )
                    dialogueApexChampion = "diag_ap_aiNotify_winnerFound_07"
                else
                    dialogueApexChampion = "diag_ap_aiNotify_winnerFound_10"
            }
            else
            {
                if ( playersOnPodium > 1 )
                    dialogueApexChampion = "diag_ap_aiNotify_winnerFound_08"
                else
                    dialogueApexChampion = "diag_ap_ainotify_introchampion_01_02"
            }

            EmitSoundOnEntityAfterDelay( platformModel, dialogueApexChampion, 0.5 )
        // }
		
		VictoryCameraPackage victoryCameraPackage
		victoryCameraPackage.camera_offset_start = <0, 320, 68>
		victoryCameraPackage.camera_offset_end = <140, 200, 48>
		if(CoinFlip()) victoryCameraPackage.camera_offset_end = <-200, 200, 48>
		victoryCameraPackage.camera_focus_offset = <0, 0, 40>
		//victoryCameraPackage.camera_fov = 20
	
		vector camera_offset_start = victoryCameraPackage.camera_offset_start
		vector camera_offset_end   = victoryCameraPackage.camera_offset_end
		vector camera_focus_offset = victoryCameraPackage.camera_focus_offset
		
		vector camera_start_pos = OffsetPointRelativeToVector( file.victorySequencePosition, camera_offset_start, AnglesToForward( file.victorySequenceAngles ) )
		vector camera_end_pos   = OffsetPointRelativeToVector( file.victorySequencePosition, camera_offset_end, AnglesToForward( file.victorySequenceAngles ) )
		vector camera_focus_pos = OffsetPointRelativeToVector( file.victorySequencePosition, camera_focus_offset, AnglesToForward( file.victorySequenceAngles ) )
		vector camera_start_angles = VectorToAngles( camera_focus_pos - camera_start_pos )
		vector camera_end_angles   = VectorToAngles( camera_focus_pos - camera_end_pos )

        //Create camera and mover
		entity cameraMover = CreateClientsideScriptMover( $"mdl/dev/empty_model.rmdl", camera_start_pos, camera_start_angles )
		entity camera      = CreateClientSidePointCamera( camera_start_pos, camera_start_angles, 28 )
		player.SetMenuCameraEntity( camera )
		camera.SetParent( cameraMover, "", false )
		cleanupEnts.append( camera )

		cleanupEnts.append( cameraMover )
		thread CameraMovement(cameraMover, camera_end_pos, camera_end_angles)
	}
}

void function CameraMovement(entity cameraMover, vector camera_end_pos, vector camera_end_angles)
{
	vector initialOrigin = cameraMover.GetOrigin()
	vector initialAngles = cameraMover.GetAngles()

	//Move camera to end pos
	cameraMover.NonPhysicsMoveTo( camera_end_pos, 10, 0.0, 6 / 2.0 )
	cameraMover.NonPhysicsRotateTo( camera_end_angles, 10, 0.0, 6 / 2.0 )	
	// wait 3
	// if(!IsValid(cameraMover)) return
	// cameraMover.NonPhysicsMoveTo( initialOrigin, 5, 0.0, 5 / 2.0 )
	// cameraMover.NonPhysicsRotateTo( initialAngles, 5, 0.0, 5 / 2.0 )	
}

void function AddWinningSquadData( int index, int eHandle)
{
	if ( index == -1 )
	{
		file.winnerSquadSummaryData.playerData.clear()
		file.winnerSquadSummaryData.squadPlacement = -1
		return
	}

	SquadSummaryPlayerData data
	data.eHandle = eHandle
	file.winnerSquadSummaryData.playerData.append( data )
	file.winnerSquadSummaryData.squadPlacement = 1
}

void function VictorySequenceOrderPlayerFirst( entity player )
{
	int playerEHandle = player.GetEncodedEHandle()
	bool hadLocalPlayer = false
	array<SquadSummaryPlayerData> playerDataArray
	SquadSummaryPlayerData localPlayerData

	foreach( SquadSummaryPlayerData data in file.winnerSquadSummaryData.playerData )
	{
		if ( data.eHandle == playerEHandle )
		{
			localPlayerData = data
			hadLocalPlayer = true
			continue
		}

		playerDataArray.append( data )
	}

	file.winnerSquadSummaryData.playerData = playerDataArray
	if ( hadLocalPlayer )
		file.winnerSquadSummaryData.playerData.insert( 0, localPlayerData )
}

vector function GetVictorySquadFormationPosition( vector mainPosition, vector angles, int index )
{
	if ( index == 0 )
		return mainPosition - <0, 0, 8>

	float offset_side = 48.0
	float offset_back = -28.0

	int groupOffsetIndex = index / 3
	int internalGroupOffsetIndex = index % 3

	float internalGroupOffsetSide = 34.0                                                                                           
	float internalGroupOffsetBack = -38.0                                                                              

	float groupOffsetSide = 114.0                                                                                            
	float groupOffsetBack = -64.0                                                                               

	float finalOffsetSide = ( groupOffsetSide * ( groupOffsetIndex % 2 == 0 ? 1 : -1 ) * ( groupOffsetIndex == 0 ? 0 : 1 ) ) + ( internalGroupOffsetSide * ( internalGroupOffsetIndex % 2 == 0 ? 1 : -1 ) * ( internalGroupOffsetIndex == 0 ? 0 : 1 ) )
	float finalOffsetBack = ( groupOffsetBack * ( groupOffsetIndex == 0 ? 0 : 1 ) ) + ( internalGroupOffsetBack * ( internalGroupOffsetIndex == 0 ? 0 : 1 ) )

	vector offset = < finalOffsetSide, finalOffsetBack, -8 >
	return OffsetPointRelativeToVector( mainPosition, offset, AnglesToForward( angles ) )
}

array<void functionref( entity, ItemFlavor, int )> s_callbacks_OnVictoryCharacterModelSpawned