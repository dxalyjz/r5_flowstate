//Flowstate 1v1 gamemode
//made by makimakima#5561
globalize_all_functions

global struct soloLocStruct
{
	LocPair &Loc1 //player1 respawn location
	LocPair &Loc2 //player2 respawn location
	array<LocPair> respawnLocations
	vector Center //center of Loc1 and Loc2

	entity Panel //keep current opponent panel

}
global struct soloGroupStruct
{
	entity player1
	entity player2

	entity ring//ring boundaries

	int slotIndex
	bool IsFinished = false //player1 or player2 is died, set this to true and soloModeThread() will handle this
	bool IsKeep = false //player may want to play with current opponent,so we will keep this group
}
global struct soloPlayerStruct
{
	entity player
	float waitingTime //players may want to play with random opponent(or a matched opponent), so adding a waiting time after they died can allow server to match proper opponent
	float kd //stored this player's kd to help server match proper opponent
	entity lastOpponent //opponent of last round
	bool IsTimeOut = false
}
global array <soloLocStruct> soloLocations //all respawn location stored here
global array <soloPlayerStruct> soloPlayersWaiting = [] //waiting player stored here
global array <soloGroupStruct> soloPlayersInProgress = [] //playing player stored here
global array <entity> soloPlayersResting = []


int function getTimeOutPlayerAmount()
{
	int timeOutPlayerAmount = 0
	foreach (eachPlayerStruct in soloPlayersWaiting )
	{
		if(eachPlayerStruct.IsTimeOut)
			timeOutPlayerAmount++
	}
	return timeOutPlayerAmount
}
entity function getTimeOutPlayer()
{
	foreach (eachPlayerStruct in soloPlayersWaiting )
	{
		if(eachPlayerStruct.IsTimeOut)
			return eachPlayerStruct.player
	}
	entity p
	return p
}
void function soloModeWaitingPrompt(entity player)
{
	wait 1
	if(!IsValid(player)) return
	foreach (eachplayerStruct in soloPlayersWaiting)
	{
		if(eachplayerStruct.player == player) //this player is in waiting list
			Message(player,"You're in waiting room.","Type rest in console to start resting (literally).",1)
	}

}

LocPair function getWaitingRoomLocation(string mapName)
{
	LocPair WaitingRoom
	if(mapName == "mp_rr_arena_composite")
	{
		WaitingRoom.origin = <-7.62,200,184.57>
		WaitingRoom.angles = <0,90,0>
	}
	else if (mapName == "mp_rr_aqueduct")
	{
		WaitingRoom.origin = <719.94,-5805.13,494.03>
		WaitingRoom.angles = <0,90,0>
	}
	
	return WaitingRoom
}

int function getAvailableSlotIndex()
{
	array<int> soloLocationInProgressIndexs //所有正在游玩的地区编号
	foreach (eachGroup in soloPlayersInProgress)
	{
		soloLocationInProgressIndexs.append(eachGroup.slotIndex)
	}

	array<int> availableSoloLocationIndex
	for (int i = 0; i < soloLocations.len(); ++i)
	{
		if(!soloLocationInProgressIndexs.contains(i))
			availableSoloLocationIndex.append(i)
	}

	printt("available slot :" + availableSoloLocationIndex.len())
	if(availableSoloLocationIndex.len()==0)
		return -1 //no available slot
	return availableSoloLocationIndex[RandomInt(availableSoloLocationIndex.len())]
}

soloGroupStruct function returnSoloGroupOfPlayer(entity player)
{
	foreach (eachGroup in soloPlayersInProgress)
	{
		if (player == eachGroup.player1 || player == eachGroup.player2)
			return eachGroup
	}
	soloGroupStruct group
	return group
}

void function endSpectate(entity player)
{
	player.SetSpecReplayDelay( 0 )
	player.SetObserverTarget( null )
	player.StopObserverMode()
    Remote_CallFunction_NonReplay(player, "ServerCallback_KillReplayHud_Deactivate")
    player.MakeVisible()
    player.ClearInvulnerable()
	player.SetTakeDamageType( DAMAGE_YES )
	try
	{
		player.Die( null, null, { damageSourceId = eDamageSourceId.damagedef_suicide } )
	}
	catch (error)
	{}
    RemoveButtonPressedPlayerInputCallback(player, IN_JUMP,endSpectate)
}

bool function isPlayerInSoloMode(entity player)
{
	foreach (eachGroup in soloPlayersInProgress)
	{
	   	if (eachGroup.player1 == player || eachGroup.player2 == player) //找到当前玩家的group
	   		return true
	}
	return false
}

bool function isPlayerInWatingList(entity player)
{
	foreach (eachPlayerStruct in soloPlayersWaiting)
	{
	   	if (eachPlayerStruct.player == player) //找到当前玩家的group
	   		return true
	}
	return false
}

bool function isPlayerInRestingList(entity player)
{
	foreach (eachPlayer in soloPlayersResting)
	{
	   	if (eachPlayer == player) //找到当前玩家的group
	   		return true
	}
	return false
}

void function deleteWaitingPlayer(entity player)
{
	if(!IsValid(player)) return
	foreach (eachPlayerStruct in soloPlayersWaiting )
	{
		if(eachPlayerStruct.player == player)
		{
			soloPlayersWaiting.removebyvalue(eachPlayerStruct) //delete this PlayerStruct
			printt("deleted the PlayerStruct")
		}
	}
}

bool function ClientCommand_Maki_SoloModeRest(entity player, array<string> args)
{
	if(soloPlayersResting.contains(player))
	{
		
		try
		{
			Message(player,"Matching!")
			soloModePlayerToWaitingList(player)
			player.Die( null, null, { damageSourceId = eDamageSourceId.damagedef_suicide } )
		}
		catch (error)
		{}
	}
	else
	{
		
		
		try
		{
			Message(player,"You are resting now", "Type rest in console to pew pew again.")
			soloModePlayerToRestingList(player)
			player.Die( null, null, { damageSourceId = eDamageSourceId.damagedef_suicide } )
		}
		catch (error)
		{

		}

		thread respawnInSoloMode(player)

	}

	return true
}

entity function getRandomOpponentOfPlayer(entity player)
{
	entity p
	if(!IsValid(player)) return p
	foreach (eachPlayerStruct in soloPlayersWaiting)
	{
		if(IsValid(eachPlayerStruct.player) && player != eachPlayerStruct.player)
			return eachPlayerStruct.player
	}

	return p
}

entity function returnOpponentOfPlayer(entity player )
{
	entity p
	soloGroupStruct group = returnSoloGroupOfPlayer(player)
	if(!IsValid(group) || !IsValid(player)) return p
	entity player1 = group.player1
	entity player2 = group.player2

	if(player == group.player1)
	{
		return player2
	}
	else if (player == group.player2)
	{
		return player1
	}

	return p
}

void function soloModePlayerToWaitingList(entity player)
{
	if(!IsValid(player)) return
	// Warning("Try to add a player to wating list: " + player.GetPlayerName())

	//检查waiting list是否有该玩家
	bool IsAlreadyExist = false
	foreach (eachPlayerStruct in soloPlayersWaiting)
	{
		if(player == eachPlayerStruct.player)
		{
			IsAlreadyExist = true
			return //waiting list里已存在该玩家,返回
		}
	}

	soloPlayerStruct playerStruct
	playerStruct.player = player
	playerStruct.waitingTime = Time() + 2
	if(IsValid(player))
		playerStruct.kd = getkd(player.GetPlayerGameStat( PGS_KILLS ),player.GetPlayerGameStat( PGS_DEATHS ))
	else
		playerStruct.kd = 0
	playerStruct.lastOpponent = player.p.lastKiller

	if(!IsAlreadyExist) //如果waiting list里没有这个玩家
	{
		soloPlayersWaiting.append(playerStruct)
	}
	else //如果waiting list里有这个玩家
	{
		return //waiting list里已存在该玩家,返回
	}

	//检查InProgress是否存在该玩家
	foreach (eachGroup in soloPlayersInProgress)
	{
		if(player == eachGroup.player1 || player == eachGroup.player2)
		{

			soloGroupStruct group = returnSoloGroupOfPlayer(player)
			entity opponent = returnOpponentOfPlayer(player)

			if(IsValid(soloLocations[group.slotIndex].Panel)) //Panel in current Location
				soloLocations[group.slotIndex].Panel.SetSkin(1) //set panel to red(default color)

			destroyRingsForGroup(eachGroup) //delete rings
			soloPlayersInProgress.removebyvalue(eachGroup) //delete this group

			soloModePlayerToWaitingList(player) //force put this player to waiting list
			if(!IsValid(opponent)) continue //opponent is not vaild
			soloModePlayerToWaitingList(opponent) //force put opponent to waiting list
		}
	}

	//检查resting list 是否有该玩家
	soloPlayersResting.removebyvalue(player)
}

bool function soloModePlayerToInProgressList(soloGroupStruct newGroup) //不能重复添加玩家,否则会导致现有的group被销毁
{

	entity player = newGroup.player1
	entity opponent = newGroup.player2
	bool result = false
	if(!IsValid(player) || !IsValid(opponent)) return result
	if(player == opponent)
	{
		// Warning("Try to add same players to InProgress list:" + player.GetPlayerName())
		return result
	}

	//检查InProgress是否存在该玩家
	bool IsAlreadyExist = false
	foreach (eachGroup in soloPlayersInProgress)
	{
		if(player == eachGroup.player1 || player == eachGroup.player2 || opponent == eachGroup.player1 || opponent == eachGroup.player2)
		{
			IsAlreadyExist = true
			destroyRingsForGroup(eachGroup)
			soloPlayersInProgress.removebyvalue(eachGroup) //销毁这个group

			// Warning("[ERROR]Try to add a exist player of InProgress list to InProgress list") //不应该出现这种情况
			return result
		}
	}

	if(!IsAlreadyExist)
	{
		newGroup.player1 = player
		newGroup.player2 = opponent
		result = true
	}
	else
	{
		// Warning("[ERROR]Try to add a exist player of InProgress list to InProgress list") //不应该出现这种情况
		return result//unreached
	}

	//检查waiting list是否有该玩家
	deleteWaitingPlayer(player)
	deleteWaitingPlayer(opponent)

	//检查resting list 是否有该玩家
	soloPlayersResting.removebyvalue(player)//将两个玩家移出resting list
	soloPlayersResting.removebyvalue(opponent)//将两个玩家移出resting list

	int slotIndex = getAvailableSlotIndex()
	if (slotIndex > -1) //available slot exist
	{
		printt("solo slot exist")
		newGroup.slotIndex = slotIndex

		printt("add player1&player2 to InProgress list!")
		soloPlayersInProgress.append(newGroup) //加入游玩队列

		result = true
	}
	else
	{
		// Warning("No avaliable slot")
		result = false
	}

	return result
}

void function soloModePlayerToRestingList(entity player)
{
	if(!IsValid(player)) return

	deleteWaitingPlayer(player)


	soloGroupStruct group = returnSoloGroupOfPlayer(player)
	if(IsValid(group))
	{
		entity opponent = returnOpponentOfPlayer(player)

		if(IsValid(soloLocations[group.slotIndex].Panel)) //Panel in current Location
			soloLocations[group.slotIndex].Panel.SetSkin(1) //set panel to red(default color)

		destroyRingsForGroup(group)
		soloPlayersInProgress.removebyvalue(group) //销毁这个group

		if(IsValid(opponent)) //找不到对手
			soloModePlayerToWaitingList(opponent) //将对手放回waiting list
	}



	foreach (eachPlayer in soloPlayersResting )
	{
		if(player == eachPlayer)//玩家重复进入resting list
		{
			soloPlayersResting.removebyvalue(player) //可以清空在resting list里的重复玩家
		}
	}

	soloPlayersResting.append(player)
}

void function soloModefixDelayStart(entity player)
{
	Message(player,"Loading solo mode")
	
	if(!isPlayerInRestingList(player))
	{
		HolsterAndDisableWeapons(player)
		wait 5
		soloModePlayerToWaitingList(player)
		try
		{
			player.Die( null, null, { damageSourceId = eDamageSourceId.damagedef_suicide } )
		}
		catch (error)
		{}
	}
	else
	{
		maki_tp_player(player,getWaitingRoomLocation(GetMapName()))
	}

	
}

void function setRealms_1v1(entity ent,int realmIndex)
{
	if(!IsValid(ent)) return
	if(realmIndex>63)
	{
		ent.AddToAllRealms()
		return
	}//add to all realms for player

	array<int> realms = ent.GetRealms()
	ent.AddToRealm(realmIndex)
	realms.removebyvalue(realmIndex)
	if(realms.len()>0)
	{
		foreach (eachRealm in realms )
		{
			ent.RemoveFromRealm(eachRealm)
		}
	}
}

void function destroyRingsForGroup(soloGroupStruct group)
{
	if(!IsValid(group)) return
	if(!IsValid(group.ring)) return
	group.ring.Destroy()
}//delete rings

entity function CreateSmallRingBoundary(vector Center)
{
    vector smallRingCenter = Center
	float smallRingRadius = 1200
	entity smallcircle = CreateEntity( "prop_script" )
	smallcircle.SetValueForModelKey( $"mdl/fx/ar_survival_radius_1x100.rmdl" )
	smallcircle.kv.fadedist = 2000
	smallcircle.kv.modelscale = smallRingRadius
	smallcircle.kv.renderamt = 1
	smallcircle.kv.rendercolor = FlowState_RingColor()
	smallcircle.kv.solid = 0
	smallcircle.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE
	smallcircle.SetOrigin( smallRingCenter )
	smallcircle.SetAngles( <0, 0, 0> )
	smallcircle.NotSolid()
	smallcircle.DisableHibernation()
	smallcircle.RemoveFromAllRealms()

	DispatchSpawn(smallcircle)

	return smallcircle
}

entity function createForbiddenZone(vector zoneOrigin, float radius,float AboveHeight = 50,float BelowHeight = 15)
{
	entity trigger = CreateEntity( "trigger_cylinder" )
	trigger.SetRadius( radius )
	trigger.SetAboveHeight( AboveHeight )
	trigger.SetBelowHeight( BelowHeight )
	trigger.SetOrigin( zoneOrigin )
	trigger.SetEnterCallback(  forbiddenZone_enter )
	trigger.SetLeaveCallback(  forbiddenZone_leave )
	trigger.SearchForNewTouchingEntity()
	// DebugDrawCylinder( trigger.GetOrigin() , < -90, 0, 0 >, radius, trigger.GetAboveHeight(), 0, 165, 255, true, 9999.9 )
	// DebugDrawCylinder( trigger.GetOrigin() , < -90, 0, 0 >, radius, -trigger.GetBelowHeight(), 255, 90, 0, true, 9999.9 )
	DispatchSpawn( trigger )
	return trigger
}

void function forbiddenZoneInit(string mapName)
{
	array<vector> triggerList 
	if(mapName == "mp_rr_aqueduct")
		triggerList = [
						<8693.24,-1103.93,571.29>,
						<-4805,-2543.85,553.75>,
					]
	else
	{
		return
	}
	foreach(origin in triggerList)
	{
		createForbiddenZone(origin,600)
	}
}

void function forbiddenZone_enter(entity trigger , entity ent)
{
	if(!IsValid( ent )) return
	HolsterAndDisableWeapons( ent )
	EntityOutOfBounds( trigger, ent, null, null )
}

void function forbiddenZone_leave(entity trigger , entity ent)
{
	if(!IsValid(ent)) return
	EnableOffhandWeapons(ent)
	DeployAndEnableWeapons( ent )
	EntityBackInBounds( trigger, ent, null, null )
}

void function maki_tp_player(entity player,LocPair data)
{
	if(!IsValid(player)) return
	player.SetAngles(data.angles)
	player.SetOrigin(data.origin)
}

void function PlayerRestoreHP_1v1(entity player, float health, float shields)
{
	if(!IsValid( player )) return
	if(!IsAlive( player )) return

	player.SetHealth( health )
	Inventory_SetPlayerEquipment(player, "helmet_pickup_lv3", "helmet")
	if(shields == 0) return
	else if(shields <= 50)
		Inventory_SetPlayerEquipment(player, "armor_pickup_lv1", "armor")
	else if(shields <= 75)
		Inventory_SetPlayerEquipment(player, "armor_pickup_lv2", "armor")
	else if(shields <= 100)
		Inventory_SetPlayerEquipment(player, "armor_pickup_lv3", "armor")
	player.SetShieldHealth( shields )
}

void function giveWeaponInRandomWeaponPool(entity player)
{
	if(!IsValid(player)) return
	try
	{
		EnableOffhandWeapons( player )
		DeployAndEnableWeapons( player )

		TakeAllWeapons(player)

	    GiveRandomPrimaryWeaponMetagame(player)
		GiveRandomSecondaryWeaponMetagame(player)
		player.GiveWeapon( "mp_weapon_bolo_sword_primary", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
		if(!isPlayerInRestingList(player))
	    	player.GiveOffhandWeapon( "melee_bolo_sword", OFFHAND_MELEE, [] )
	}
	catch (e)
	{}
}

bool function isGroupVaild(soloGroupStruct group)
{
	if(!IsValid(group)) return false
	if(!IsValid(group.player1) || !IsValid(group.player2)) return false
	return true
}

void function respawnInSoloMode(entity player, int respawnSlotIndex = -1) //复活死亡玩家和同一个sologroup的玩家
{
	if (!IsValid(player)) return
	printt("respawnInSoloMode!")
	// Warning("respawn player: " + player.GetPlayerName())

   	if( player.p.isSpectating )
    {
		player.SetPlayerNetInt( "spectatorTargetCount", 0 )
		player.p.isSpectating = false
		player.SetSpecReplayDelay( 0 )
		player.SetObserverTarget( null )
		player.StopObserverMode()
        Remote_CallFunction_NonReplay(player, "ServerCallback_KillReplayHud_Deactivate")
        player.MakeVisible()
		player.ClearInvulnerable()
		player.SetTakeDamageType( DAMAGE_YES )
    }//disable replay mode

   	if( isPlayerInRestingList(player) )
	{
		// Warning("resting respawn")
		try
		{
			DecideRespawnPlayer(player, true)

			if(!(player.GetPlayerName() in weaponlist))
			{
				giveWeaponInRandomWeaponPool( player )
			}
			else
			{
				TakeAllWeapons(player)
				thread LoadCustomWeapon(player)
			}
			player.GiveWeapon( "mp_weapon_bolo_sword_primary", WEAPON_INVENTORY_SLOT_PRIMARY_2, [] )
		}
		catch (erroree)
		{
			// printt("fail to respawn")
		}
		LocPair waitingRoomLocation = getWaitingRoomLocation(GetMapName())
		if (!IsValid(waitingRoomLocation)) return

		maki_tp_player(player, waitingRoomLocation)
		player.MakeVisible()
		player.ClearInvulnerable()
		player.SetTakeDamageType( DAMAGE_YES )

		//set realms for resting player
		setRealms_1v1(player,63)//more than 63 means AddToAllRealms

		return
	}//玩家在休息模式

	soloGroupStruct group = returnSoloGroupOfPlayer(player)

	if(!isGroupVaild(group)) return //Is this group is available
	if (respawnSlotIndex == -1) return

	try
	{
		DecideRespawnPlayer(player, true)
	}
	catch (error)
	{
		// Warning("fail to respawn")
	}

	maki_tp_player(player,soloLocations[group.slotIndex].respawnLocations[respawnSlotIndex])

	wait 0.2 //防止上一条命被攻击的伤害传递到下一条命的玩家上

	if(!IsValid(player)) return
	
	Inventory_SetPlayerEquipment(player, "armor_pickup_lv3", "armor")
	PlayerRestoreHP_1v1(player, 100, player.GetShieldHealthMax().tofloat())

	//player dont need any skills in solo mode
	player.TakeOffhandWeapon(OFFHAND_TACTICAL)
	player.TakeOffhandWeapon(OFFHAND_ULTIMATE)

	if (IsValid(player) && !(player.GetPlayerName() in weaponlist))//avoid give weapon twice if player saved his guns
	{
		giveWeaponInRandomWeaponPool( player )

		WpnPulloutOnRespawn(player,0)

		wait 0.3
		if(IsValid(player))
			WpnAutoReload(player)
	}

	thread LoadCustomWeapon(player)

	thread ReCheckGodMode(player)

	//set realms for this player
	setRealms_1v1(player,group.slotIndex+1)
}

void function _soloModeInit(string mapName)
{
	array<LocPair> allSoloLocations
	array<LocPair> panelLocations
	LocPair waitingRoomPanelLocation

	if (mapName == "mp_rr_arena_composite")
	{
		waitingRoomPanelLocation = NewLocPair( <7.74,595.19,125>, <0,0,0>)//休息区观战面板

		allSoloLocations= [
		NewLocPair( <344.814117, 1279.00415, 188.561081>, <0, 178.998779, 0>), //1
		NewLocPair( <-301.836731, 1278.16309, 188.60759>, <0, -2.78833318, 0>),

		NewLocPair( <-2934.02246, 3094.91431, 192.048279>, <0, 45.9642601, 0>), //2
		NewLocPair( <-2282.98853, 3810.25732, 192.046173>, <0, -120.085022, 0>),

		NewLocPair( <-1037.84583, 2280.85938, -130.952026>, <0, -6.83472872, 0>), //3
		NewLocPair( <-143.20752, 2239.93433, -114.43261>, <0, -178.196396, 0>),

		NewLocPair( <2983.75, 3072.01416, 192.054321>, <0, 138.60434, 0>), //4
		NewLocPair( <2251.52686, 3821.51807, 192.045395>, <0, -59.6830139, 0>),

		NewLocPair( <-694.934387, 4686.71777, 128.03125>, <0, -159.394516, 0>), //5
		NewLocPair( <-1257.71802, 4618.77295, 128.017029>, <0, 7.97793579, 0>),

		NewLocPair( <-851.90686, 5469.09717, -32.0257645>, <0, -3.02725101, 0>), //6
		NewLocPair( <-209.819092, 5462.67139, -30.802206>, <0, -178.949997, 0>),

		NewLocPair( <621.688782, 3920.86963, -31.9940014>, <0, -84.1400604, 0>), //7
		NewLocPair( <709.123413, 3262.09692, -31.96875>, <0, 94.3908463, 0>),

		NewLocPair( <2933.51343, 1449.6571, 140.03125>, <0, -100.364799, 0>), //8
		NewLocPair( <2455.15234, 1004.09894, 128.03125>, <0, 7.74315786, 0>),

		NewLocPair( <-1441.08, 1675.66, 280.08>, <0, -110, 0>),//9
		NewLocPair( <-1787.21, 1008.08, 254.03>, <0, 50, 0>),//9

		NewLocPair( <1649.15588, 1135.37439, 192.03125>, <0, 137.991577, 0>), //10
		NewLocPair( <1122.84058, 1418.50452, 190.821075>, <0, -27.6340904, 0>),

		NewLocPair( <-2862.42407, 1511.31921, 140.03125>, <0, -100.470222, 0>), //11
		NewLocPair( <-2633.31348, 833.701477, 128.03125>, <0, 130.051575, 0>),

		NewLocPair( <-836.684998, 2751.19849, 192.03125>, <0, -150.722626, 0>),//12
		NewLocPair( <-1405.85583, 2548.43164, 192.03125>, <0, 12.0755987, 0>),

		NewLocPair( <-370.51,3663.66,38.05>, <0, -179, 0>),//13
		NewLocPair( <-993.01,3593.72,38.03>, <0, 0, 0>),

		NewLocPair( <325.75,5450.20,37.99>, <0, 0, 0>),//14
		NewLocPair( <791.90,5470,37.96>, <0, -179, 0>),

		NewLocPair( <-1300.11,825.80,263.59>, <0, -90, 0>),//15
		NewLocPair( <-1282.95,365.33,258.52>, <0, 99, 0>),

		NewLocPair( <1238.38599, 463.776398, 188.519135>, <0, 72.6185074, 0>),//16
		NewLocPair( <1324.41174, 981.882935, 192.03125>, <0, -91.4171066, 0>),

		NewLocPair( <1448.33447, 3317.91479, 192.03125>, <0, 68.6674118, 0>),//17
		NewLocPair( <1554.34924, 3939.51025, 207.536079>, <0, -80.6048737, 0>),
		
		NewLocPair( <249.44,2192.07,-83.95>, <0, 0, 0>),//18
		NewLocPair( <982.84,2282.03,-79.80>, <0, 180, 0>),

		NewLocPair( <1349.37073, 4802.27588, 112.714142>, <0, -139.755951, 0>),//19
		NewLocPair( <961.166992, 4261.96045, 96.5980682>, <0, 51.0961037, 0>),

		NewLocPair( <-1605.22,3429.22,248.03>, <0, 83, 0>),//20
		NewLocPair( <-1435.54,4249.86,248.03>, <0, -104, 0>),

		NewLocPair( <2167.40918, 2935.69556, 192.019638>, <0, -109.743301, 0>),//21
		NewLocPair( <2172.37158, 2358.00952, 192.03125>, <0, 109.198524, 0>),
		
		NewLocPair( <828.207886, 2858.75366, 138.439407>, <0, -53.4489517, 0>),//22
		NewLocPair( <1273.42163, 2863.05151, 192.03125>, <0, -126.334923, 0>),

		NewLocPair( <324.865631, 4042.37549, -32.0016365>, <0, 104.08799, 0>),//23
		NewLocPair( <300.957703, 5219.19727, -31.9992428>, <0, -100.332466, 0>),
		
		NewLocPair( <3288.1748, 1603.40466, 140.03125>, <0, 58.516037, 0>),//24
		NewLocPair( <3215.24048, 2158.63452, 129.175247>, <0, -19.0440102, 0>),
		
		NewLocPair( <-2092.07983, 2377.82764, 192.03125>, <0, 84.2584991, 0>),//25
		NewLocPair( <-2328.0144, 2979.53149, 192.034607>, <0, -44.2118797, 0>),
		
		]

		//panel
		panelLocations = [
			NewLocPair( <-4.90188408, 1580.82349, 188.526581>, <0, 0, 0>),//1
			NewLocPair( <-2513.19702, 3376.53174, 192.048309>, <0, 50, 0>),//2
			NewLocPair( <-517.093201, 2170.28882, -143.956406>, <0, 0, 0>),//3
			NewLocPair( <2622.61, 3294.64, 190.05>, <0, -40, 0>),//4
			NewLocPair( <-894.18, 4539.96, 130.03>, <0, 30, 0>),//5
			NewLocPair( <-582.68, 5138.91, -30.02>, <0, 180, 0>),//6
			NewLocPair( <609.73, 3556.99, -30.03>, <0, -80, 0>),//7
			NewLocPair( <2998.07, 840.03, 140>, <0, -115, 0>),//8
			NewLocPair( <-1627.84, 1568.45, 190>, <0, 0, 0>),//9
			NewLocPair( <1268.07, 1527.68, 190>, <0, 0, 0>),//10
			NewLocPair( <-2969.78, 810.96, 140>, <0, 120, 0>),//11
			NewLocPair( <-1073.46, 2685.75, 190>, <0, -43, 0>),//12
			NewLocPair( <-716.40,3495.84,-30>, <0, -15, 0>),//13
			NewLocPair( <591.95,5142.56,-30>, <0, 179, 0>),//14
			NewLocPair( <-1530.68,500.86,190.03>, <0, -105, 0>),//15
			NewLocPair( <1556.98523, 597.19342, 200.03125>, <0, 90, 0>),//16
			NewLocPair( <1887.17041, 3503.83081, 195.039398>, <0, -98.78875732, 0>),//17
			NewLocPair( <526.66,2170.51,-140.96>, <0, 10, 0>),//18
			NewLocPair( <985.612549, 4648.27246, 130.03125>, <0, 70.373337, 0>),//19
			NewLocPair( <-1600.47,3786.78,190>, <0, -140, 0>),//20
			NewLocPair( <2089.88184, 2744.64038, 192.006805>, <0, -94.4084015, 0>),//21
			NewLocPair( <1112.74988, 2514.03906, 192.067337>, <0, -161.284119, 0>),//22
			NewLocPair( <-227.960938, 4824.87207, -23.0877609>, <0, 90.380486, 0>),//23
			NewLocPair( <3707.19995, 1743.08301, 140.03125>, <0, -129.417236, 0>),//24
			NewLocPair( <-2103.71606, 2601.79492, 192.053299>, <0, 104.140854, 0>),//25

		]
		}
		else if (mapName == "mp_rr_aqueduct")
		{
			waitingRoomPanelLocation = NewLocPair( <718.29,-5496.74,430>, <0,0,0>) //休息区观战面板

			allSoloLocations= [

			NewLocPair( <-6775.57568, -204.993729, 106.120445>, <0, -32.8351936, 0>),//1
			NewLocPair( <-6230.72607, -527.870239, 107.595337>, <0, 144.085541, 0>),

			NewLocPair( <3263.02002, -3556.06055, 273.576324>, <0, 8.61375999, 0>),//2
			NewLocPair( <3784.31885, -3452.91772, 272.03125>, <0, -171.17247, 0>),

			NewLocPair( <8502.62109, -615.898987, 315.014832>, <0, -60.9690781, 0>),//3
			NewLocPair( <9021.84863, -1498.87195, 310.646271>, <0, 117.371147, 0>),

			NewLocPair( <167.032883, -6722.06787, 336.03125>, <0, -1.60793841, 0>),//4
			NewLocPair( <1296.91602, -6719.25293, 336.03125>, <0, 178.672043, 0>),

			NewLocPair( <-761.57,-4554.79,311.46>, <0, -144.43, 0>),//5
			NewLocPair( <-1436.52,-5086.34,299.21>, <0, 40.96, 0>),

			NewLocPair( <2809.94946, -4459.84961, 361.746124>, <0, -88.6163712, 0>),//6
			NewLocPair( <2738.16772, -5504.04443, 388.564209>, <0, 82.8682785, 0>),

			NewLocPair( <-444.894531, -2472.0481, -313.453186>, <0, -6.28803873, 0>),//7
			NewLocPair( <34.082859, -2517.09546, -311.32724>, <0, 170.668167, 0>),

			NewLocPair( <2050.9939, -3850.13452, 432.03125>, <0, -174.60405, 0>),//8
			NewLocPair( <1504.50134, -3880.59595, 432.03125>, <0, 0.203577876, 0>),

			NewLocPair( <234.719513, -4128.62842, 273.224884>, <0, -94.9567108, 0>),//9
			NewLocPair( <214.551025, -4557.26904, 272.03125>, <0, 87.0343704, 0>),

			NewLocPair( <-5046.05176, -2948.47144, 314.250671>, <0, 63.9120026, 0>),//10
			NewLocPair( <-4553.3623, -2102.83643, 313.807098>, <0, -119.961533, 0>),

			NewLocPair( <-2457.16333, -5476.83203, 400.03125>, <0, -12.8816891, 0>),//11
			NewLocPair( <-1929.41846, -5594.64307, 400.03125>, <0, 165.039886, 0>),

			NewLocPair( <-81.694252, -3906.92749, 432.03125>, <0, 171.290192, 0>),//12
			NewLocPair( <-640.369202, -3834.13794, 432.03125>, <0, -13.2758875, 0>),

			NewLocPair( <-3015.57031, -3553.14819, 272.03125>, <0, -140.035995, 0>),//13
			NewLocPair( <-3493.69263, -4762.4126, 272.032166>, <0, 84.9091492, 0>),

			NewLocPair( <4900.87,-4851.21,342.03>, <0, 84, 0>),//14
			NewLocPair( <4523.58,-4314.47,359.03>, <0, -50, 0>),

			NewLocPair( <1104.35,-5061.49,241.89>, <0, 150, 0>),//15
			NewLocPair( <268.09,-5116.85,254.11>, <0, 35, 0>),

			NewLocPair( <236.687241, -3286.51929, 194.174698>, <0, 2.6228354, 0>),//16
			NewLocPair( <1190.59399, -3279.21387, 189.531311>, <0, 175.707504, 0>),


			NewLocPair( <2316.1394, -6255.12891, 272.03125>, <0, -135.394714, 0>),//17
			NewLocPair( <1492.8938, -6749.38281, 336.03125>, <0, 16.5300903, 0>),


			NewLocPair( <-2373.8894, -4067.91235, 272.03125>, <0, -11.765295, 0>),//18
			NewLocPair( <-1605.19885, -4356.48682, 272.03125>, <0, 167.221832, 0>),


			NewLocPair( <1546.54614, -3925.69653, 432.03125>, <0, 178.18158, 0>),//19
			NewLocPair( <-88.5635071, -3930.20972, 432.03125>, <0, -3.95487189, 0>),


			NewLocPair( <-1357.79187, -2538.92139, -177.872864>, <0, 161.874039, 0>),//20
			NewLocPair( <-1712.66296, -2455.35352, -179.737701>, <0, -15.1608248, 0>),


			NewLocPair( <4686.76953, -4032.88989, 289.03125>, <0, 128.110565, 0>),//21
			NewLocPair( <4325.82275, -3579.64404, 272.03125>, <0, -38.2275581, 0>),
			

			NewLocPair( <3235.31445, -2440.99512, -170.73761>, <0, -174.955383, 0>),//22
			NewLocPair( <2659.73682, -2574.521, -169.679779>, <0, 10.7634172, 0>),
			

			NewLocPair( <2091.56885, -5355.79199, 272.03125>, <0, 168.726898, 0>),//23
			NewLocPair( <1703.44958, -5388.27637, 272.03125>, <0, 33.2674942, 0>),
			

			NewLocPair( <1201.47375, -4569.81885, 272.03125>, <0, 102.834091, 0>),//24
			NewLocPair( <1174.39063, -4099.19482, 272.03125>, <0, -86.6457367, 0>),
			

			NewLocPair( <509.780792, -3553.27417, 272.03125>, <0, -32.6431389, 0>),//25
			NewLocPair( <940.882507, -3571.79614, 272.03125>, <0, -165.179703, 0>),
			

			NewLocPair( <-1011.33984, -5737.27686, 272.03125>, <0, 160.994431, 0>),//26
			NewLocPair( <-1450.14954, -5626.41504, 291.342773>, <0, -29.6448517, 0>),
			

			NewLocPair( <-2114.90674, -5093.61523, 400.15564>, <0, -17.1056633, 0>),//27
			NewLocPair( <-1705.21277, -5217.26758, 400.15567>, <0, 162.525665, 0>),
			

			]
			panelLocations = [
				NewLocPair( <-6357.56, -110.40, -95.07>, <0, -30, 0>),//1
				NewLocPair( <3551.47, -3581.74, 270.03>, <0, 0, 0>),//2
				NewLocPair( <9136.70, -797.05, 310.17>, <0, -60, 0>),//3
				NewLocPair( <718.50, -7027.66, 330.03>, <0, 170, 0>),//4
				NewLocPair( <-962.44, -4706.85, 190.77>, <0, -10, 0>),//5
				NewLocPair( <3035.04, -4838.01, 400.16>, <0, -80, 0>),//6
				NewLocPair( <-179.10, -2264.64, -390.97>, <0, 0, 0>),//7
				NewLocPair( <1810.83, -3773.77, 430.03>, <0, -179, 0>),//8
				NewLocPair( <451.17, -4365.68, 270.03>, <0, -90, 0>),//9
				NewLocPair( <-4515.57, -2811.07, 310.31>, <0, -120, 0>),//10
				NewLocPair( <-2278.44, -5838.17, 400.03>, <0, 160, 0>),//11
				NewLocPair( <-301.65, -4238.32, 430.03>, <0, 160, 0>),//12
				NewLocPair( <-3079.95, -4274.58, 290.03>, <0, -120, 0>),//13
				NewLocPair( <5190.85,-4526.38,290.03>, <0, -70, 0>),//14
				NewLocPair( <695.27,-4614.08,260.32>, <0, 0, 0>),//15
				NewLocPair( <708.920288, -2988.02588, -9.62331676>, <0, 0, 0>),//16
				NewLocPair( <1870.75488, -6479.83447, 400.03125>, <0, 30, 0>),//17
				NewLocPair( <-1978.19421, -4416.03223, 236.325821>, <0, -20, 0>),//18
				NewLocPair( <699.656738, -3733.9458, 472.10907>, <0, 0, 0>),//19
				NewLocPair( <-1591.87451, -2729.90186, -22.8790321>, <0, 170, 0>),//20
				NewLocPair( <4786.11816, -3532.48218, 289.03125>, <0, -62.8320656, 0>),//21
				NewLocPair( <3009.39917, -2712.67188, -34.4465103>, <0, -170.362656, 0>),//22
				NewLocPair( <1864.15967, -4985.94287, 171.889587>, <0, 4.93536282, 0>),//23
				NewLocPair( <1411.21692, -4292.29199, 272.03125>, <0, -78.5810471, 0>),//24
				NewLocPair( <711.917542, -3850.45361, 272.03125>, <0, -179.304123, 0>),//25
				NewLocPair( <-1193.65161, -5708.77441, 273.224915>, <0, -9.75974274, 0>),//26
				NewLocPair( <-1848.05164, -4968.32764, 400.15564>, <0, -9.37366867, 0>),//27

			]
		}
		else
		{
			return
		}

	//resting room init


	entity restingRoomPanel = CreateFRButton(waitingRoomPanelLocation.origin, waitingRoomPanelLocation.angles, "%&use% Start spectating")
	AddCallback_OnUseEntity( restingRoomPanel, void function(entity panel, entity user, int input)
	{
		if(!IsValid(user)) return
		if(!isPlayerInRestingList(user))
		{
			Message(user,"Your must be in resting mode to spectate others!","Input 'rest' in console to enter resting mode ")
			return //不在休息队列中不能使用观战功能
		}


	    try
	    {
	    	array<entity> enemiesArray = GetPlayerArray_Alive()
			enemiesArray.fastremovebyvalue( user )
		    entity specTarget = enemiesArray.getrandom()

	    	user.p.isSpectating = true
			user.SetPlayerNetInt( "spectatorTargetCount", GetPlayerArray().len() )
			user.SetObserverTarget( specTarget )
			user.SetSpecReplayDelay( 0.5 )
			user.StartObserverMode( OBS_MODE_IN_EYE )
			thread CheckForObservedTarget(user)
			user.p.lastTimeSpectateUsed = Time()

			Message(user,"Press 'SPACE' to stop spectating")
			user.MakeInvisible()

	    }
	    catch (error333)
	    {}
	    AddButtonPressedPlayerInputCallback( user, IN_JUMP,endSpectate  )
	})



	for (int i = 0; i < allSoloLocations.len(); i=i+2)
	{
		soloLocStruct p

		p.respawnLocations.append(allSoloLocations[i])
		p.respawnLocations.append(allSoloLocations[i+1])

		p.Center = (allSoloLocations[i].origin + allSoloLocations[i+1].origin)/2

		soloLocations.append(p)
	}

	foreach (index,eahclocation in panelLocations)
	{
		//Panels for save opponents
		entity panel = CreateFRButton(eahclocation.origin, eahclocation.angles, "%&use% Never change your opponent")
		panel.SetSkin(1)//red
		soloLocations[index].Panel = panel
		AddCallback_OnUseEntity( panel, void function(entity panel, entity user, int input)
		{
			soloGroupStruct group = returnSoloGroupOfPlayer(user)
			if(!isGroupVaild(group)) return //Is this group is available
			if (soloLocations[group.slotIndex].Panel != panel) return //有傻逼捣乱

			if( group.IsKeep == false)
			{
				group.IsKeep = true
				panel.SetSkin(0) //green

				try
				{
					Message(group.player1,"Your opponent won't change")
					Message(group.player2,"Your opponent won't change")
				}
				catch (error)
				{}

				
			}
			else
			{
				group.IsKeep = false
				panel.SetSkin(1) //red

				try
				{
					Message(group.player1,"Your opponent will change now")
					Message(group.player2,"Your opponent will change now")
				}
				catch (error)
				{}
			}
		})//AddCallback_OnUseEntity
	}//foreach


	forbiddenZoneInit(GetMapName())
	thread soloModeThread(getWaitingRoomLocation(GetMapName()))

}

void function soloModeThread(LocPair waitingRoomLocation)
{
	printt("solo mode thread start!")

	wait 8
	while(true)
	{
		WaitFrame()
		//遍历等待队列
		foreach (playerInWatingSctruct in soloPlayersWaiting )
		{
			if(!IsValid(playerInWatingSctruct.player))
			{
				// Warning("PLAYER QUIT")
				soloPlayersWaiting.removebyvalue(playerInWatingSctruct)
				continue
			}

			if(Distance2D(playerInWatingSctruct.player.GetOrigin(),waitingRoomLocation.origin)>500) //waiting player should be in waiting room,not battle area
			{
				thread soloModeWaitingPrompt(playerInWatingSctruct.player)
				maki_tp_player(playerInWatingSctruct.player,waitingRoomLocation) //waiting player should be in waiting room,not battle area
				HolsterAndDisableWeapons(playerInWatingSctruct.player)
			}


			//标记超时玩家
			if(playerInWatingSctruct.waitingTime < Time() && !playerInWatingSctruct.IsTimeOut && IsValid(playerInWatingSctruct.player))
			{
				printt("mark time out player: " + playerInWatingSctruct.player.GetPlayerName() + " waitingTime: " + playerInWatingSctruct.waitingTime)
				playerInWatingSctruct.IsTimeOut = true
			}
		}//foreach

		//遍历游玩队列
		foreach (eachGroup in soloPlayersInProgress)
		{
			if(eachGroup.IsFinished)//this round has been finished
			{
				printt("this round has been finished")
				soloModePlayerToWaitingList(eachGroup.player1)
				soloModePlayerToWaitingList(eachGroup.player2)
				destroyRingsForGroup(eachGroup)
				continue
			}

			if(eachGroup.IsKeep) //player in this group dont want to change opponent
			{
				if(IsValid(eachGroup.player1) && IsValid(eachGroup.player2) && (!IsAlive(eachGroup.player1) || !IsAlive(eachGroup.player2) ))
				{
					printt("respawn and tp player1")
					thread respawnInSoloMode(eachGroup.player1, 0)

					printt("respawn and tp player2")
					thread respawnInSoloMode(eachGroup.player2, 1)
				}//player in keeped group is died, respawn them
			}

			if(!IsValid(eachGroup.player1) || !IsValid(eachGroup.player2)) //Is player in this group quit the game
			{
				printt("solo player quit!!!!!")
				bool isEmptyGroup = false
				if(IsValid(eachGroup.player1))
				{
					soloModePlayerToWaitingList(eachGroup.player1) //back to wating list
					Message(eachGroup.player1,"Your opponent has disconnected!")
					isEmptyGroup = true
				}

				if(IsValid(eachGroup.player2))
				{
					soloModePlayerToWaitingList(eachGroup.player2) //back to wating list
					Message(eachGroup.player2,"Your opponent has disconnected!")
					isEmptyGroup = true
				}

				if(isEmptyGroup)
				{
					if(IsValid(soloLocations[eachGroup.slotIndex].Panel)) //Panel in current Location
						soloLocations[eachGroup.slotIndex].Panel.SetSkin(1) //set panel to red(default color)
					destroyRingsForGroup(eachGroup) //delete rings
					soloPlayersInProgress.removebyvalue(eachGroup) //delete this group
				}
				continue//to do: delete the last group when server is empty
			}

			//检测乱跑的脑残
			int eachSlotIndex = eachGroup.slotIndex
			vector Center =  soloLocations[eachSlotIndex].Center
			array<entity> players = [eachGroup.player1,eachGroup.player2]
			foreach (eachPlayer in players )
			{
				if(!IsValid(eachPlayer)) continue
				eachPlayer.p.lastDamageTime = Time() //avoid player regen health

				if(Distance2D(eachPlayer.GetOrigin(),Center) > 1200) //检测乱跑的脑残
				{
					Remote_CallFunction_Replay( eachPlayer, "ServerCallback_PlayerTookDamage", 0, 0, 0, 0, DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, eDamageSourceId.deathField, null )
					eachPlayer.TakeDamage( 1, null, null, { scriptType = DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.deathField } )
				}
			}
		}//foreach




		//遍历休息队列
		foreach (restingPlayer in soloPlayersResting )
		{
			if(!IsValid(restingPlayer)) continue
			TakeAmmoFromPlayer(restingPlayer)   //子弹设为0
			if(!IsAlive(restingPlayer)  )
			{
				thread respawnInSoloMode(restingPlayer)
			}


		}


		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//开始匹配
		if(soloPlayersWaiting.len()<2) //等待队列人数不足,无法开始匹配
		{
			continue
		}

		// printt("------------------more than 2 player in solo waiting array,matching------------------")
		soloGroupStruct newGroup
		entity opponent
		//优先处理超时玩家
		//player1:超时的玩家,player2:随机从等待队列里找一个玩家

		if(getTimeOutPlayerAmount() > 0)//存在已经超时的玩家
		{
			// Warning("Time out matching")
			newGroup.player1 = getTimeOutPlayer()  //获取超时的玩家
			if(IsValid(newGroup.player1))//存在超时等待玩家
			{
				// printt("Time out player found: " + newGroup.player1.GetPlayerName())
				opponent = getRandomOpponentOfPlayer(newGroup.player1)
				if(IsValid(opponent))
					newGroup.player2 = opponent
			}
		}//超时玩家处理结束
		else//不存在已超时玩家,正常按照kd匹配
		{
			// Warning("Normal matching")
			foreach (eachPlayerStruct in soloPlayersWaiting ) //找player1
			{
				entity playerSelf = eachPlayerStruct.player
				float selfKd = eachPlayerStruct.kd
				table <entity,float> properOpponentTable
				foreach (eachOpponentPlayerStruct in soloPlayersWaiting ) //找player2
				{
					entity eachOpponent = eachOpponentPlayerStruct.player
					float opponentKd = eachOpponentPlayerStruct.kd
					if(playerSelf == eachOpponent || !IsValid(eachOpponent))//过滤非法对手
						continue

					if(fabs(selfKd - opponentKd) > 1) //过滤kd差值
						continue
					properOpponentTable[eachOpponent] <- fabs(selfKd - opponentKd)
				}

				float lowestKd = 999
				entity bestOpponent
				entity scondBestOpponent//防止bestOpponent是上一局的对手
				foreach (opponentt,kd in properOpponentTable)
				{

					if(kd < lowestKd)
					{
						scondBestOpponent = bestOpponent
						bestOpponent = opponentt
						lowestKd = kd
					}
				}

				entity lastOpponent = eachPlayerStruct.lastOpponent

				if(!IsValid(bestOpponent)) continue//没找到最合适玩家,为下一位玩家匹配
				if(bestOpponent != lastOpponent) //最合适玩家是上局对手,用第二合适玩家代替
				{
					// Warning("Best opponent, kd gap: " + lowestKd)
					newGroup.player1 = playerSelf
					newGroup.player2 = bestOpponent
					break
				}
				else if (IsValid(scondBestOpponent))
				{
					// Warning("Secondary opponent, kd gap: " + lowestKd)
					newGroup.player1 = playerSelf
					newGroup.player2 = scondBestOpponent
					break
				}
				else
				{
					// Warning("Only last opponent found, waiting for time out")
					continue //上局对手是最合适玩家,且没有第二合适对手,开始为下一位玩家匹配
				}
			}//foreach
		}//else

		if(! (IsValid(newGroup.player1) && IsValid(newGroup.player2))     ) //确保两个玩家都是合法玩家
		{
			// Warning("player Invalid, back to waiting list")
			soloModePlayerToWaitingList(newGroup.player1)
			soloModePlayerToWaitingList(newGroup.player2)
			continue
		}

		//already matched two players
		array<entity> players = [newGroup.player1,newGroup.player2]

		soloModePlayerToInProgressList(newGroup)

		foreach (index,eachPlayer in players )
		{
			EnableOffhandWeapons( eachPlayer )
			DeployAndEnableWeapons( eachPlayer )

			thread respawnInSoloMode(eachPlayer, index)
		}
		newGroup.ring = CreateSmallRingBoundary(soloLocations[newGroup.slotIndex].Center)
		setRealms_1v1(newGroup.ring,newGroup.slotIndex+1) //set ring's realms, newGroup.slotIndex+1 to ensure realms is more than 0
		//realms = 0 means visible for everyone,so it should be more than 0
		setRealms_1v1(newGroup.player1,newGroup.slotIndex+1) //set player's realms, newGroup.slotIndex+1 to ensure realms is more than 0
		setRealms_1v1(newGroup.player2,newGroup.slotIndex+1) //set player's realms, newGroup.slotIndex+1 to ensure realms is more than 0

	}//while(true)

	OnThreadEnd(
		function() : (  )
		{
			// Warning(Time() + "Solo thread is down!!!!!!!!!!!!!!!")
			GameRules_ChangeMap( GetMapName(), GameRules_GetGameMode() )
		}
	)

}//thread






