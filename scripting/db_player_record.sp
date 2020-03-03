/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.
	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

enum
{
	Arg_Steam2ID,
	Arg_Steam3ID,
	Arg_Steam32ID,
	Arg_Steam64ID,
	Arg_Name,
	Arg_IP,
}

// Cvars
ConVar g_cvarPrintChat;
ConVar g_cvarPrintConsole;
ConVar g_cvarPrintServer;

// Cvars Buffer
int g_iPrintChat;
int g_iPrintConsole;
int g_iPrintServer;

Database g_hDatabase = null;

public Plugin myinfo = {
	name = "Player Info Recorder",
	author = "Mis",
	description = "Saves info about each player that connects to the server in a database.",
	version = "0.1.0",
	url = "https://github.com/misdocumeno/"
};

////////////////////////////////////////////////////////////////
// Stock Functions
////////////////////////////////////////////////////////////////

public void OnPluginStart()
{
	// ConVars
	g_cvarPrintChat = CreateConVar("db_playerrecord_printchat", "0", "Set whether the command response should be seen in the chat.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarPrintConsole = CreateConVar("db_playerrecord_printconsole", "1", "Set whether the command response should be seen in the client console.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarPrintServer = CreateConVar("db_playerrecord_printserver", "0", "Set whether the command response should be seen in the server console.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_iPrintChat = GetConVarInt(g_cvarPrintChat);
	g_iPrintConsole = GetConVarInt(g_cvarPrintConsole);
	g_iPrintServer = GetConVarInt(g_cvarPrintServer);

	HookConVarChange(g_cvarPrintChat, OnConVarChange);
	HookConVarChange(g_cvarPrintConsole, OnConVarChange);
	HookConVarChange(g_cvarPrintServer, OnConVarChange);

	// Info commands
	RegAdminCmd("sm_playerinfo", OnPlayerInfoCMD, ADMFLAG_UNBAN, "Shows names, all types of SteamID and IPs seen with a given SteamID of any type, IP or name.");
	RegAdminCmd("sm_nameinfo", OnNameInfoCMD, ADMFLAG_UNBAN, "Shows names, all types of SteamID and IPs seen with a given name.");
	RegAdminCmd("sm_ipinfo", OnIpInfoCMD, ADMFLAG_UNBAN, "Shows names, all types of SteamID and IPs of all players who have joined the server from the given IP.");
	RegAdminCmd("sm_steamid2info", OnSteamId2InfoCMD, ADMFLAG_UNBAN, "Shows last name, all types of SteamID and last seen IP explicitly searching with a SteamID2.");
	RegAdminCmd("sm_steamid3info", OnSteamId3InfoCMD, ADMFLAG_UNBAN, "Shows last name, all types of SteamID and last seen IP explicitly searching with a SteamID3.");
	RegAdminCmd("sm_steamid64info", OnSteamId64InfoCMD, ADMFLAG_UNBAN, "Shows last name, all types of SteamID, and last seen IP explicitly searching with a SteamID64.");

	// History commands	
	RegAdminCmd("sm_playerall", OnPlayerAllCMD, ADMFLAG_UNBAN, "Shows a history of all names, all types of SteamID and all IPs of a given SteamID of any type, IP or name.");
	RegAdminCmd("sm_namenames", OnNameNamesCMD, ADMFLAG_UNBAN, "Shows a history of all names that a player had searching with one of his names.");
	RegAdminCmd("sm_steamid2names", OnSteamId2NamesCMD, ADMFLAG_UNBAN, "Shows a history of all names a player had searching with a SteamID2.");
	RegAdminCmd("sm_steamid3names", OnSteamId3NamesCMD, ADMFLAG_UNBAN, "Shows a history of all names a player had searching with a SteamID3.");
	RegAdminCmd("sm_steamid64names", OnSteamId64NamesCMD, ADMFLAG_UNBAN, "Shows a history of all names a player had searching with a SteamID64.");
	RegAdminCmd("sm_nameips", OnNameIpsCMD, ADMFLAG_UNBAN, "Shows a history of all IPs connected with the given name.");
	RegAdminCmd("sm_steamid2ips", OnSteamId2IpsCMD, ADMFLAG_UNBAN, "Shows a history of all IPs from where a SteamID2 was connected.");
	RegAdminCmd("sm_steamid3ips", OnSteamId3IpsCMD, ADMFLAG_UNBAN, "Shows a history of all IPs from where a SteamID3 was connected.");
	RegAdminCmd("sm_steamid64ips", OnSteamId64IpsCMD, ADMFLAG_UNBAN, "Shows a history of all IPs from where a SteamID64 was connected.");
	RegAdminCmd("sm_ipall", OnIpAllCMD, ADMFLAG_UNBAN, "Shows a history of all types of SteamID and their respective names seen on an IP.");

	HookEvent("player_changename", OnPlayerChangeName_Event, EventHookMode_Post);

	Database.Connect(SQL_FirstConnect, "PlayerRecord");
}

public void OnConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvarPrintChat)
		g_iPrintChat = GetConVarInt(g_cvarPrintChat);
	else if (convar == g_cvarPrintConsole)
		g_iPrintConsole = GetConVarInt(g_cvarPrintConsole);
	else if (convar == g_cvarPrintServer)
		g_iPrintServer = GetConVarInt(g_cvarPrintServer);
}

public void OnClientAuthorized(int client)
{
	char sIP[16];
	char sUserName[MAX_NAME_LENGTH];
	int iAccountId = GetSteamAccountID(client);
	bool bValidIP = GetClientIP(client, sIP, sizeof(sIP));
	bool bValidName = GetClientName(client, sUserName, sizeof(sUserName));

	if (iAccountId != 0 && bValidIP && bValidName)
	{
		char query[256];

		g_hDatabase.Format(query, sizeof(query), "INSERT INTO "
			..."`Players`(`AccountID`, `IP`, `Name`) "
			..."VALUES ('%i', '%s', '%s') ON DUPLICATE KEY UPDATE "
			..."`Date` = CURRENT_TIMESTAMP", iAccountId, sIP, sUserName);

		g_hDatabase.Query(SQL_CreateAndInsertQuery, query);		
	}
}

public Action OnPlayerChangeName_Event(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	char sIP[16];
	char sUserName[MAX_NAME_LENGTH];
	int iAccountId = GetSteamAccountID(client);
	bool bValidIP = GetClientIP(client, sIP, sizeof(sIP));
	event.GetString("newname", sUserName, sizeof(sUserName));

	if (iAccountId != 0 && bValidIP)
	{
		char query[256];

		g_hDatabase.Format(query, sizeof(query), "INSERT INTO "
			..."`Players`(`AccountID`, `IP`, `Name`) "
			..."VALUES ('%i', '%s', '%s') ON DUPLICATE KEY UPDATE "
			..."`Date` = CURRENT_TIMESTAMP", iAccountId, sIP, sUserName);

		g_hDatabase.Query(SQL_CreateAndInsertQuery, query);		
	}
}

////////////////////////////////////////////////////////////////
// Commands Functions
////////////////////////////////////////////////////////////////

static Action OnPlayerInfoCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_playerinfo {olive}<name/SteamID/IP>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_playerinfo <name/SteamID/IP>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_playerinfo <name/SteamID/IP>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	if (GetArgType(arg) == Arg_Steam2ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam2ID);
	else if (GetArgType(arg) == Arg_Steam3ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam3ID);
	else if (GetArgType(arg) == Arg_Steam32ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam32ID);
	else if (GetArgType(arg) == Arg_Steam64ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam64ID);
	else if (GetArgType(arg) == Arg_Name)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam64ID);

	char query[256];

	if (GetArgType(arg) == Arg_Name)
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%s' GROUP BY `Players`.`AccountID` ORDER BY `Players`.`Date`", arg);
	else if (GetArgType(arg) == Arg_IP)
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE IP = '%s' GROUP BY `Players`.`AccountID` ORDER BY `Players`.`Date`", arg);
	else
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE AccountID = '%i' ORDER BY `Players`.`Date` DESC LIMIT 1", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hPlayerInfoPack = new DataPack();
	hPlayerInfoPack.WriteString(arg);
	hPlayerInfoPack.WriteCell(userid);
	hPlayerInfoPack.WriteCell(GetArgType(arg));	

	g_hDatabase.Query(OnInfoQuery, query, hPlayerInfoPack);

	return Plugin_Handled;
}

static Action OnNameInfoCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_nameinfo {olive}<name>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_nameinfo <name>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_nameinfo <name>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%s' GROUP BY `Players`.`AccountID` ORDER BY `Players`.`Date`", arg);

	int userid = GetClientUserId(client);

	DataPack hPlayerInfoPack = new DataPack();
	hPlayerInfoPack.WriteString(arg);
	hPlayerInfoPack.WriteCell(userid);
	hPlayerInfoPack.WriteCell(Arg_Name);	

	g_hDatabase.Query(OnInfoQuery, query, hPlayerInfoPack);

	return Plugin_Handled;
}

static Action OnIpInfoCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_ipinfo {olive}<IP>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_ipinfo <IP>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_ipinfo <IP>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE IP = '%s' GROUP BY `Players`.`AccountID` ORDER BY `Players`.`Date`", arg);

	int userid = GetClientUserId(client);

	DataPack hPlayerInfoPack = new DataPack();
	hPlayerInfoPack.WriteString(arg);
	hPlayerInfoPack.WriteCell(userid);
	hPlayerInfoPack.WriteCell(Arg_IP);	

	g_hDatabase.Query(OnInfoQuery, query, hPlayerInfoPack);

	return Plugin_Handled;
}

static Action OnSteamId2InfoCMD(int client, any args)
{	
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid2info {olive}<SteamID2>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid2info <SteamID2>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid2info <SteamID2>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam2ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE AccountID = '%i' ORDER BY `Players`.`Date` DESC LIMIT 1", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hPlayerInfoPack = new DataPack();
	hPlayerInfoPack.WriteString(arg);
	hPlayerInfoPack.WriteCell(userid);
	hPlayerInfoPack.WriteCell(Arg_Steam2ID);	

	g_hDatabase.Query(OnInfoQuery, query, hPlayerInfoPack);

	return Plugin_Handled;
}

static Action OnSteamId3InfoCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid3info {olive}<SteamID3>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid3info <SteamID3>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid3info <SteamID3>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam3ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE AccountID = '%i' ORDER BY `Players`.`Date` DESC LIMIT 1", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hPlayerInfoPack = new DataPack();
	hPlayerInfoPack.WriteString(arg);
	hPlayerInfoPack.WriteCell(userid);
	hPlayerInfoPack.WriteCell(Arg_Steam3ID);	

	g_hDatabase.Query(OnInfoQuery, query, hPlayerInfoPack);

	return Plugin_Handled;
}

static Action OnSteamId64InfoCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid64info {olive}<SteamID64>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid64info <SteamID64>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid64info <SteamID64>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam64ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE AccountID = '%i' ORDER BY `Players`.`Date` DESC LIMIT 1", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hPlayerInfoPack = new DataPack();
	hPlayerInfoPack.WriteString(arg);
	hPlayerInfoPack.WriteCell(userid);
	hPlayerInfoPack.WriteCell(Arg_Steam64ID);	

	g_hDatabase.Query(OnInfoQuery, query, hPlayerInfoPack);

	return Plugin_Handled;
}

////////////////////////////////////////////////////////////////

static Action OnPlayerAllCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_playerall {olive}<name/SteamID/IP>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_playerall <name/SteamID/IP>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_playerall <name/SteamID/IP>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	if (GetArgType(arg) == Arg_Steam2ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam2ID);
	else if (GetArgType(arg) == Arg_Steam3ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam3ID);
	else if (GetArgType(arg) == Arg_Steam32ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam32ID);
	else if (GetArgType(arg) == Arg_Steam64ID)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam64ID);
	else if (GetArgType(arg) == Arg_Name)
		iAccountId = GetAccountIdByAny(client, arg, Arg_Steam64ID);

	char query[256];

	if (GetArgType(arg) == Arg_Name)
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%s' ORDER BY `Players`.`Date` DESC", arg);
	else if (GetArgType(arg) == Arg_IP)
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE IP = '%s' ORDER BY `Players`.`Date` DESC", arg);
	else
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE AccountID = '%i' ORDER BY `Players`.`Date` DESC", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hHistoryAllPack = new DataPack();
	hHistoryAllPack.WriteString(arg);
	hHistoryAllPack.WriteCell(userid);
	hHistoryAllPack.WriteCell(GetArgType(arg));

	g_hDatabase.Query(OnHistoryAllQuery, query, hHistoryAllPack);

	return Plugin_Handled;
}

static Action OnNameNamesCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_namenames {olive}<name>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_namenames <name>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_namenames <name>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT AccountId FROM Players WHERE Name LIKE '%s'", arg);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteString(arg);

	g_hDatabase.Query(OnNameNamesGotAccountIdCMD, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnSteamId2NamesCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid2names {olive}<Steam2ID>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid2names <Steam2ID>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid2names <Steam2ID>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam2ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name FROM Players WHERE AccountID = '%i'", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);	
	hNameOrIpPack.WriteCell(Arg_Name);

	g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnSteamId3NamesCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid3names {olive}<Steam3ID>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid3names <Steam3ID>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid3names <Steam3ID>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam3ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name FROM Players WHERE AccountID = '%i'", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteCell(Arg_Name);

	g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnSteamId64NamesCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid64names {olive}<Steam64ID>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid64names <Steam64ID>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid64names <Steam64ID>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam64ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name FROM Players WHERE AccountID = '%i'", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteCell(Arg_Name);

	g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnNameIpsCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_nameips {olive}<name>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_nameips <name>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_nameips <name>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT IP FROM Players WHERE Name LIKE '%s'", arg);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteCell(Arg_IP);	

	g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnSteamId2IpsCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid2ips {olive}<Steam2ID>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid2ips <Steam2ID>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid2ips <Steam2ID>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam2ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT IP FROM Players WHERE AccountID = '%i'", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteCell(Arg_IP);	

	g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnSteamId3IpsCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid3ips {olive}<Steam3ID>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid3ips <Steam3ID>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid3ips <Steam3ID>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam3ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT IP FROM Players WHERE AccountID = '%i'", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteCell(Arg_IP);	

	g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnSteamId64IpsCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_steamid64ips {olive}<Steam64ID>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_steamid64ips <Steam64ID>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_steamid64ips <Steam64ID>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	int iAccountId;

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	iAccountId = GetAccountIdByAny(client, arg, Arg_Steam64ID);

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT IP FROM Players WHERE AccountID = '%i'", iAccountId);

	int userid = GetClientUserId(client);

	DataPack hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteCell(Arg_IP);	

	g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);

	return Plugin_Handled;
}

static Action OnIpAllCMD(int client, any args)
{
	if (args != 1)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {blue}Usage: {default}sm_ipall {olive}<IP>");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Usage: sm_ipall <IP>");
		if (g_iPrintServer)
			PrintToServer("[!] Usage: sm_ipall <IP>");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "{blue}[{green}!{blue}] {default}Searching...");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] Searching...");
		if (g_iPrintServer)
			PrintToServer("[!] Searching...");
	}

	char arg[256];
	GetCmdArg(1, arg, sizeof(arg));

	char query[256];
	g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name, AccountId FROM Players WHERE IP = '%s'", arg);

	int userid = GetClientUserId(client);

	DataPack hSteamIdPack = new DataPack();
	hSteamIdPack.WriteCell(userid);	

	g_hDatabase.Query(OnHistoryIpQuery, query, hSteamIdPack);

	return Plugin_Handled;
}

////////////////////////////////////////////////////////////////
// SQL Query Functions
////////////////////////////////////////////////////////////////

public void SQL_FirstConnect(Database db, const char[] error, any data)
{
	if (db == null || error[0] != '\0')
	{
		LogError("Database connect failure: %s", error);
		return;
	}

	g_hDatabase = db;

	g_hDatabase.SetCharset("utf8mb4");

	g_hDatabase.Query(SQL_CreateAndInsertQuery, "CREATE TABLE IF NOT EXISTS `Players`("
		..."`IndexID` INT(1) NOT NULL AUTO_INCREMENT, "
		..."`Date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL, "
		..."`AccountID` INT(1) NOT NULL, "
		..."`IP` varchar(16) NOT NULL, "
		..."`Name` varchar(256) NOT NULL, "
		..."UNIQUE INDEX `authId_IP_Name`(`AccountID`, `IP`, `Name`), "
		..."PRIMARY KEY(IndexID)"
		...") COLLATE 'utf8mb4_unicode_ci' ENGINE = InnoDB ROW_FORMAT = COMPRESSED;");
}

public void OnInfoQuery(Database db, DBResultSet results, const char[] sError, DataPack hPlayerInfoPack)
{
	char arg[256];
	hPlayerInfoPack.Reset();
	hPlayerInfoPack.ReadString(arg, sizeof(arg));
	int userid = hPlayerInfoPack.ReadCell();
	int iArgType = hPlayerInfoPack.ReadCell();
	delete hPlayerInfoPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	DataPack hInfoQuery = new DataPack();
	int iRowAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hInfoQuery.WriteString(sNameBuffer1);
		hInfoQuery.WriteString(sIPBuffer1);
		hInfoQuery.WriteString(sAccountIdBuffer1);

		iRowAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hInfoQuery.Reset();

		for (int i = 0; i < iRowAmount; i++)
		{
			if (i != 0)
				CPrintToChat(client, "{green}----------");

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hInfoQuery.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hInfoQuery.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hInfoQuery.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (iArgType == Arg_Name || iArgType == Arg_IP)
			{
				if (g_iPrintChat && client)
				{
					CPrintToChat(client, "{default}Name {green}- {olive}%s", sNameBuffer2);
					CPrintToChat(client, "{default}SteamID2 {green}- {olive}%s", sSteamId2);
					CPrintToChat(client, "{default}SteamID3 {green}- {olive}%s", sSteamId3);
					CPrintToChat(client, "{default}SteamID64 {green}- {olive}%s", sSteamId64);
					CPrintToChat(client, "{default}IP {green}- {olive}%s", sIPBuffer2);
				}

				if (g_iPrintConsole && client)
				{
					PrintToConsole(client, "Name - %s", sNameBuffer2);
					PrintToConsole(client, "SteamID2 - %s", sSteamId2);
					PrintToConsole(client, "SteamID3 - %s", sSteamId3);
					PrintToConsole(client, "SteamID64 - %s", sSteamId64);
					PrintToConsole(client, "IP - %s", sIPBuffer2);
				}

				if (g_iPrintServer)
				{
					PrintToServer("Name - %s", sNameBuffer2);
					PrintToServer("SteamID2 - %s", sSteamId2);
					PrintToServer("SteamID3 - %s", sSteamId3);
					PrintToServer("SteamID64 - %s", sSteamId64);
					PrintToServer("IP - %s", sIPBuffer2);
				}
			}
			else
			{
				if (g_iPrintChat && client)
				{
					CPrintToChat(client, "{default}Last Name {green}- {olive}%s", sNameBuffer2);
					CPrintToChat(client, "{default}SteamID2 {green}- {olive}%s", sSteamId2);
					CPrintToChat(client, "{default}SteamID3 {green}- {olive}%s", sSteamId3);
					CPrintToChat(client, "{default}SteamID64 {green}- {olive}%s", sSteamId64);
					CPrintToChat(client, "{default}Last IP {green}- {olive}%s", sIPBuffer2);
				}

				if (g_iPrintConsole && client)
				{
					PrintToConsole(client, "Last Name - %s", sNameBuffer2);
					PrintToConsole(client, "SteamID2 - %s", sSteamId2);
					PrintToConsole(client, "SteamID3 - %s", sSteamId3);
					PrintToConsole(client, "SteamID64 - %s", sSteamId64);
					PrintToConsole(client, "Last IP - %s", sIPBuffer2);
				}

				if (g_iPrintServer)
				{
					PrintToServer("Last Name - %s", sNameBuffer2);
					PrintToServer("SteamID2 - %s", sSteamId2);
					PrintToServer("SteamID3 - %s", sSteamId3);
					PrintToServer("SteamID64 - %s", sSteamId64);
					PrintToServer("Last IP - %s", sIPBuffer2);
				}
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		if (iArgType == Arg_Name)
		{
			char query[256];
			g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%%%s' GROUP BY `Players`.`AccountID` ORDER BY `Players`.`Date`", arg);

			hPlayerInfoPack = new DataPack();
			hPlayerInfoPack.WriteString(arg);
			hPlayerInfoPack.WriteCell(userid);

			g_hDatabase.Query(OnInfoQueryRetry1, query, hPlayerInfoPack);
		}
		else
		{
			if (g_iPrintChat && client)
				CPrintToChat(client, "[{green}!{default}] {red}No player found");
			if (g_iPrintConsole && client)
				PrintToConsole(client, "[!] No player found");
			if (g_iPrintServer)
				PrintToServer("[!] No player found");
		}
	}

	delete hInfoQuery;
}

public void OnInfoQueryRetry1(Database db, DBResultSet results, const char[] sError, DataPack hPlayerInfoPack)
{
	char arg[256];
	hPlayerInfoPack.Reset();
	hPlayerInfoPack.ReadString(arg, sizeof(arg));
	int userid = hPlayerInfoPack.ReadCell();
	delete hPlayerInfoPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	DataPack hInfoQuery = new DataPack();
	int iRowAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hInfoQuery.WriteString(sNameBuffer1);
		hInfoQuery.WriteString(sIPBuffer1);
		hInfoQuery.WriteString(sAccountIdBuffer1);

		iRowAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hInfoQuery.Reset();

		for (int i = 0; i < iRowAmount; i++)
		{
			if (i != 0)
				CPrintToChat(client, "{green}----------");

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hInfoQuery.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hInfoQuery.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hInfoQuery.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{default}Name {green}- {olive}%s", sNameBuffer2);
				CPrintToChat(client, "{default}SteamID2 {green}- {olive}%s", sSteamId2);
				CPrintToChat(client, "{default}SteamID3 {green}- {olive}%s", sSteamId3);
				CPrintToChat(client, "{default}SteamID64 {green}- {olive}%s", sSteamId64);
				CPrintToChat(client, "{default}IP {green}- {olive}%s", sIPBuffer2);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name - %s", sNameBuffer2);
				PrintToConsole(client, "SteamID2 - %s", sSteamId2);
				PrintToConsole(client, "SteamID3 - %s", sSteamId3);
				PrintToConsole(client, "SteamID64 - %s", sSteamId64);
				PrintToConsole(client, "IP - %s", sIPBuffer2);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name - %s", sNameBuffer2);
				PrintToServer("SteamID2 - %s", sSteamId2);
				PrintToServer("SteamID3 - %s", sSteamId3);
				PrintToServer("SteamID64 - %s", sSteamId64);
				PrintToServer("IP - %s", sIPBuffer2);
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{	
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%s%' GROUP BY `Players`.`AccountID` ORDER BY `Players`.`Date`", arg);

		hPlayerInfoPack = new DataPack();
		hPlayerInfoPack.WriteString(arg);
		hPlayerInfoPack.WriteCell(userid);

		g_hDatabase.Query(OnInfoQueryRetry2, query, hPlayerInfoPack);
	}

	delete hInfoQuery;
}

public void OnInfoQueryRetry2(Database db, DBResultSet results, const char[] sError, DataPack hPlayerInfoPack)
{
	char arg[256];
	hPlayerInfoPack.Reset();
	hPlayerInfoPack.ReadString(arg, sizeof(arg));
	int userid = hPlayerInfoPack.ReadCell();
	delete hPlayerInfoPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	DataPack hInfoQuery = new DataPack();
	int iRowAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hInfoQuery.WriteString(sNameBuffer1);
		hInfoQuery.WriteString(sIPBuffer1);
		hInfoQuery.WriteString(sAccountIdBuffer1);

		iRowAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hInfoQuery.Reset();

		for (int i = 0; i < iRowAmount; i++)
		{
			if (i != 0)
				CPrintToChat(client, "{green}----------");

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hInfoQuery.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hInfoQuery.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hInfoQuery.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));
			
			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{default}Name {green}- {olive}%s", sNameBuffer2);
				CPrintToChat(client, "{default}SteamID2 {green}- {olive}%s", sSteamId2);
				CPrintToChat(client, "{default}SteamID3 {green}- {olive}%s", sSteamId3);
				CPrintToChat(client, "{default}SteamID64 {green}- {olive}%s", sSteamId64);
				CPrintToChat(client, "{default}IP {green}- {olive}%s", sIPBuffer2);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name - %s", sNameBuffer2);
				PrintToConsole(client, "SteamID2 - %s", sSteamId2);
				PrintToConsole(client, "SteamID3 - %s", sSteamId3);
				PrintToConsole(client, "SteamID64 - %s", sSteamId64);
				PrintToConsole(client, "IP - %s", sIPBuffer2);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name - %s", sNameBuffer2);
				PrintToServer("SteamID2 - %s", sSteamId2);
				PrintToServer("SteamID3 - %s", sSteamId3);
				PrintToServer("SteamID64 - %s", sSteamId64);
				PrintToServer("IP - %s", sIPBuffer2);
			}	
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%%%s%%' GROUP BY `Players`.`AccountID` ORDER BY `Players`.`Date`", arg);
		
		hPlayerInfoPack = new DataPack();
		hPlayerInfoPack.WriteString(arg);
		hPlayerInfoPack.WriteCell(userid);

		g_hDatabase.Query(OnInfoQueryRetry3, query, hPlayerInfoPack);
	}

	delete hInfoQuery;
}

public void OnInfoQueryRetry3(Database db, DBResultSet results, const char[] sError, DataPack hPlayerInfoPack)
{
	char arg[256];
	hPlayerInfoPack.Reset();
	hPlayerInfoPack.ReadString(arg, sizeof(arg));
	int userid = hPlayerInfoPack.ReadCell();
	delete hPlayerInfoPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	DataPack hInfoQuery = new DataPack();
	int iRowAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hInfoQuery.WriteString(sNameBuffer1);
		hInfoQuery.WriteString(sIPBuffer1);
		hInfoQuery.WriteString(sAccountIdBuffer1);

		iRowAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hInfoQuery.Reset();

		for (int i = 0; i < iRowAmount; i++)
		{
			if (i != 0)
				CPrintToChat(client, "{green}----------");

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hInfoQuery.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hInfoQuery.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hInfoQuery.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{default}Name {green}- {olive}%s", sNameBuffer2);
				CPrintToChat(client, "{default}SteamID2 {green}- {olive}%s", sSteamId2);
				CPrintToChat(client, "{default}SteamID3 {green}- {olive}%s", sSteamId3);
				CPrintToChat(client, "{default}SteamID64 {green}- {olive}%s", sSteamId64);
				CPrintToChat(client, "{default}IP {green}- {olive}%s", sIPBuffer2);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name - %s", sNameBuffer2);
				PrintToConsole(client, "SteamID2 - %s", sSteamId2);
				PrintToConsole(client, "SteamID3 - %s", sSteamId3);
				PrintToConsole(client, "SteamID64 - %s", sSteamId64);
				PrintToConsole(client, "IP - %s", sIPBuffer2);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name - %s", sNameBuffer2);
				PrintToServer("SteamID2 - %s", sSteamId2);
				PrintToServer("SteamID3 - %s", sSteamId3);
				PrintToServer("SteamID64 - %s", sSteamId64);
				PrintToServer("IP - %s", sIPBuffer2);
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {red}No player found");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] No player found");
		if (g_iPrintServer)
			PrintToServer("[!] No player found");
	}

	delete hInfoQuery;
}

////////////////////////////////////////////////////////////////

public void OnNameNamesGotAccountIdCMD(Database db, DBResultSet results, const char[] sError, DataPack hNameOrIpPack)
{
	hNameOrIpPack.Reset();
	int userid = hNameOrIpPack.ReadCell();
	char arg[MAX_NAME_LENGTH];
	hNameOrIpPack.ReadString(arg, sizeof(arg));
	delete hNameOrIpPack;

	char sAccountId[32];

	while (results.FetchRow())
		results.FetchString(0, sAccountId, sizeof(sAccountId));

	hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteString(arg);

	if (results.RowCount != 0)
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name FROM Players WHERE AccountID = '%s'", sAccountId);

		g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);
	}
	else
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT AccountId FROM Players WHERE Name LIKE '%%%s'", arg);

		g_hDatabase.Query(OnNameNamesGotAccountIdCMDRetry1, query, hNameOrIpPack);
	}
}

public void OnNameNamesGotAccountIdCMDRetry1(Database db, DBResultSet results, const char[] sError, DataPack hNameOrIpPack)
{
	hNameOrIpPack.Reset();
	int userid = hNameOrIpPack.ReadCell();
	char arg[MAX_NAME_LENGTH];
	hNameOrIpPack.ReadString(arg, sizeof(arg));
	delete hNameOrIpPack;

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	char sAccountId[32];

	while (results.FetchRow())
		results.FetchString(0, sAccountId, sizeof(sAccountId));

	hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteString(arg);


	if (results.RowCount != 0)
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name FROM Players WHERE AccountID = '%s'", sAccountId);

		g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);
	}
	else
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT AccountId FROM Players WHERE Name LIKE '%s%'", arg);

		g_hDatabase.Query(OnNameNamesGotAccountIdCMDRetry2, query, hNameOrIpPack);
	}	
}

public void OnNameNamesGotAccountIdCMDRetry2(Database db, DBResultSet results, const char[] sError, DataPack hNameOrIpPack)
{
	hNameOrIpPack.Reset();
	int userid = hNameOrIpPack.ReadCell();
	char arg[MAX_NAME_LENGTH];
	hNameOrIpPack.ReadString(arg, sizeof(arg));

	delete hNameOrIpPack;

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	char sAccountId[32];

	while (results.FetchRow())
		results.FetchString(0, sAccountId, sizeof(sAccountId));

	hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);
	hNameOrIpPack.WriteString(arg);


	if (results.RowCount != 0)
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name FROM Players WHERE AccountID = '%s'", sAccountId);

		g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);
	}
	else
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT AccountId FROM Players WHERE Name LIKE '%%%s%%'", arg);

		g_hDatabase.Query(OnNameNamesGotAccountIdCMDRetry3, query, hNameOrIpPack);
	}
}

public void OnNameNamesGotAccountIdCMDRetry3(Database db, DBResultSet results, const char[] sError, DataPack hNameOrIpPack)
{
	hNameOrIpPack.Reset();
	int userid = hNameOrIpPack.ReadCell();
	char arg[MAX_NAME_LENGTH];
	hNameOrIpPack.ReadString(arg, sizeof(arg));
	delete hNameOrIpPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	char sAccountId[32];

	while (results.FetchRow())
		results.FetchString(0, sAccountId, sizeof(sAccountId));

	hNameOrIpPack = new DataPack();
	hNameOrIpPack.WriteCell(userid);

	if (results.RowCount != 0)
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT DISTINCT Name FROM Players WHERE AccountID = '%s'", sAccountId);

		g_hDatabase.Query(OnHistoryQuery, query, hNameOrIpPack);
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {red}No player found");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] No player found");
		if (g_iPrintServer)
			PrintToServer("[!] No player found");
	}
}

////////////////////////////////////////////////////////////////

public void OnHistoryQuery(Database db, DBResultSet results, const char[] sError, DataPack hNameOrIpPack)
{
	hNameOrIpPack.Reset();
	int userid = hNameOrIpPack.ReadCell();
	delete hNameOrIpPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if (!client)
		return;

	DataPack hNameOrIpHistory = new DataPack();
	int iNameOrIpHistoryAmount;

	while (results.FetchRow())
	{
		char sNameOrIpBuffer1[MAX_NAME_LENGTH];
		results.FetchString(0, sNameOrIpBuffer1, sizeof(sNameOrIpBuffer1));
		hNameOrIpHistory.WriteString(sNameOrIpBuffer1);
		iNameOrIpHistoryAmount++;
	}

	if (results.RowCount > 0)
	{
		hNameOrIpHistory.Reset();

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		for (int i = 0; i < iNameOrIpHistoryAmount; i++)
		{
			char sNameOrIpBuffer2[MAX_NAME_LENGTH];
			hNameOrIpHistory.ReadString(sNameOrIpBuffer2, sizeof(sNameOrIpBuffer2));

			if (g_iPrintChat && client)
				CPrintToChat(client, "{olive}%s", sNameOrIpBuffer2);
			if (g_iPrintConsole && client)
				PrintToConsole(client, "%s", sNameOrIpBuffer2);
			if (g_iPrintServer)
				PrintToServer("%s", sNameOrIpBuffer2);
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {red}No player found");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] No player found");
		if (g_iPrintServer)
			PrintToServer("[!] No player found");
	}

	delete hNameOrIpHistory;
}

////////////////////////////////////////////////////////////////

public void OnHistoryIpQuery(Database db, DBResultSet results, const char[] sError, DataPack hSteamIdPack)
{
	hSteamIdPack.Reset();
	int userid = hSteamIdPack.ReadCell();
	delete hSteamIdPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if (!client)
		return;

	DataPack hSteamIdHistory = new DataPack();
	int iSteamIdHistoryAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[32];
		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		hSteamIdHistory.WriteString(sNameBuffer1);
		
		char sSteamIdBuffer1[32];
		results.FetchString(1, sSteamIdBuffer1, sizeof(sSteamIdBuffer1));
		hSteamIdHistory.WriteString(sSteamIdBuffer1);

		iSteamIdHistoryAmount++;
	}

	if (results.RowCount > 0)
	{
		hSteamIdHistory.Reset();

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		for (int i = 0; i < iSteamIdHistoryAmount; i++)
		{
			if (i != 0)
			{	
				if (g_iPrintChat && client)
					CPrintToChat(client, "{green}----------");
				if (g_iPrintConsole && client)
					PrintToConsole(client, "----------");
				if (g_iPrintServer)
					PrintToServer("----------");
			}

			char sNameBuffer2[MAX_NAME_LENGTH];
			hSteamIdHistory.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			char sSteamIdBuffer2[MAX_NAME_LENGTH];
			hSteamIdHistory.ReadString(sSteamIdBuffer2, sizeof(sSteamIdBuffer2));

			int iAccountId = StringToInt(sSteamIdBuffer2);
			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "Name: {olive}%s"
					..."\n{default}SteamId2: {olive}%s"
					..."\n{default}SteamId3: {olive}%s"
					..."\n{default}SteamId64: {olive}%s", sNameBuffer2, sSteamId2, sSteamId3, sSteamId64);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name: %s"
					..."\nSteamId2: %s"
					..."\nSteamId3: %s"
					..."\nSteamId64: %s", sNameBuffer2, sSteamId2, sSteamId3, sSteamId64);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name: %s"
					..."\nSteamId2: %s"
					..."\nSteamId3: %s"
					..."\nSteamId64: %s", sNameBuffer2, sSteamId2, sSteamId3, sSteamId64);
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {red}No player found");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] No player found");
		if (g_iPrintServer)
			PrintToServer("[!] No player found");
	}

	delete hSteamIdHistory;
}

////////////////////////////////////////////////////////////////

public void OnHistoryAllQuery(Database db, DBResultSet results, const char[] sError, DataPack hHistoryAllPack)
{
	char arg[256];
	hHistoryAllPack.Reset();
	hHistoryAllPack.ReadString(arg, sizeof(arg));
	int userid = hHistoryAllPack.ReadCell();
	int iArgType = hHistoryAllPack.ReadCell();
	delete hHistoryAllPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if (!client)
		return;

	DataPack hAllHistory = new DataPack();
	int iAllHistoryAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hAllHistory.WriteString(sNameBuffer1);
		hAllHistory.WriteString(sIPBuffer1);
		hAllHistory.WriteString(sAccountIdBuffer1);
		iAllHistoryAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hAllHistory.Reset();

		for (int i = 0; i < iAllHistoryAmount; i++)
		{
			if (i != 0)
			{	
				if (g_iPrintChat && client)
					CPrintToChat(client, "{green}----------");
				if (g_iPrintConsole && client)
					PrintToConsole(client, "----------");
				if (g_iPrintServer)
					PrintToServer("----------");
			}

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hAllHistory.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hAllHistory.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hAllHistory.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{default}Name: {olive}%s", sNameBuffer2);
				CPrintToChat(client, "{default}SteamId2: {olive}%s", sSteamId2);
				CPrintToChat(client, "{default}SteamId3: {olive}%s", sSteamId3);
				CPrintToChat(client, "{default}SteamId64: {olive}%s", sSteamId64);
				CPrintToChat(client, "{default}IP: {olive}%s", sIPBuffer2);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name: %s", sNameBuffer2);
				PrintToConsole(client, "SteamId2: %s", sSteamId2);
				PrintToConsole(client, "SteamId3: %s", sSteamId3);
				PrintToConsole(client, "SteamId64: %s", sSteamId64);
				PrintToConsole(client, "IP: %s", sIPBuffer2);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name: %s", sNameBuffer2);
				PrintToServer("SteamId2: %s", sSteamId2);
				PrintToServer("SteamId3: %s", sSteamId3);
				PrintToServer("SteamId64: %s", sSteamId64);
				PrintToServer("IP: %s", sIPBuffer2);
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		if (iArgType == Arg_Name)
		{
			char query[256];
			g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%%%s' ORDER BY `Players`.`Date` DESC", arg);

			hHistoryAllPack = new DataPack();
			hHistoryAllPack.WriteCell(userid);
			hHistoryAllPack.WriteString(arg);

			g_hDatabase.Query(OnInfoQueryRetry1, query, hHistoryAllPack);
		}
		else
		{
			if (g_iPrintChat && client)
				CPrintToChat(client, "[{green}!{default}] {red}No player found");
			if (g_iPrintConsole && client)
				PrintToConsole(client, "[!] No player found");
			if (g_iPrintServer)
				PrintToServer("[!] No player found");
		}
	}

	delete hAllHistory;
}

public void OnHistoryAllQueryRetry1(Database db, DBResultSet results, const char[] sError, DataPack hHistoryAllPack)
{
	char arg[256];
	hHistoryAllPack.Reset();
	int userid = hHistoryAllPack.ReadCell();
	hHistoryAllPack.ReadString(arg, sizeof(arg));
	delete hHistoryAllPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	DataPack hAllHistory = new DataPack();
	int iAllHistoryAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hAllHistory.WriteString(sNameBuffer1);
		hAllHistory.WriteString(sIPBuffer1);
		hAllHistory.WriteString(sAccountIdBuffer1);
		iAllHistoryAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hAllHistory.Reset();

		for (int i = 0; i < iAllHistoryAmount; i++)
		{
			if (i != 0)
			{	
				if (g_iPrintChat && client)
					CPrintToChat(client, "{green}----------");
				if (g_iPrintConsole && client)
					PrintToConsole(client, "----------");
				if (g_iPrintServer)
					PrintToServer("----------");
			}

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hAllHistory.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hAllHistory.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hAllHistory.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{default}Name: {olive}%s", sNameBuffer2);
				CPrintToChat(client, "{default}SteamId2: {olive}%s", sSteamId2);
				CPrintToChat(client, "{default}SteamId3: {olive}%s", sSteamId3);
				CPrintToChat(client, "{default}SteamId64: {olive}%s", sSteamId64);
				CPrintToChat(client, "{default}IP: {olive}%s", sIPBuffer2);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name: %s", sNameBuffer2);
				PrintToConsole(client, "SteamId2: %s", sSteamId2);
				PrintToConsole(client, "SteamId3: %s", sSteamId3);
				PrintToConsole(client, "SteamId64: %s", sSteamId64);
				PrintToConsole(client, "IP: %s", sIPBuffer2);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name: %s", sNameBuffer2);
				PrintToServer("SteamId2: %s", sSteamId2);
				PrintToServer("SteamId3: %s", sSteamId3);
				PrintToServer("SteamId64: %s", sSteamId64);
				PrintToServer("IP: %s", sIPBuffer2);
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%s%' ORDER BY `Players`.`Date` DESC", arg);

		hHistoryAllPack = new DataPack();
		hHistoryAllPack.WriteCell(userid);
		hHistoryAllPack.WriteString(arg);

		g_hDatabase.Query(OnInfoQueryRetry2, query, hHistoryAllPack);
	}

	delete hAllHistory;
}

public void OnHistoryAllQueryRetry2(Database db, DBResultSet results, const char[] sError, DataPack hHistoryAllPack)
{
	char arg[256];
	hHistoryAllPack.Reset();
	int userid = hHistoryAllPack.ReadCell();
	hHistoryAllPack.ReadString(arg, sizeof(arg));
	delete hHistoryAllPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	DataPack hAllHistory = new DataPack();
	int iAllHistoryAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hAllHistory.WriteString(sNameBuffer1);
		hAllHistory.WriteString(sIPBuffer1);
		hAllHistory.WriteString(sAccountIdBuffer1);
		iAllHistoryAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hAllHistory.Reset();

		for (int i = 0; i < iAllHistoryAmount; i++)
		{
			if (i != 0)
			{	
				if (g_iPrintChat && client)
					CPrintToChat(client, "{green}----------");
				if (g_iPrintConsole && client)
					PrintToConsole(client, "----------");
				if (g_iPrintServer)
					PrintToServer("----------");
			}

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hAllHistory.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hAllHistory.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hAllHistory.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{default}Name: {olive}%s", sNameBuffer2);
				CPrintToChat(client, "{default}SteamId2: {olive}%s", sSteamId2);
				CPrintToChat(client, "{default}SteamId3: {olive}%s", sSteamId3);
				CPrintToChat(client, "{default}SteamId64: {olive}%s", sSteamId64);
				CPrintToChat(client, "{default}IP: {olive}%s", sIPBuffer2);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name: %s", sNameBuffer2);
				PrintToConsole(client, "SteamId2: %s", sSteamId2);
				PrintToConsole(client, "SteamId3: %s", sSteamId3);
				PrintToConsole(client, "SteamId64: %s", sSteamId64);
				PrintToConsole(client, "IP: %s", sIPBuffer2);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name: %s", sNameBuffer2);
				PrintToServer("SteamId2: %s", sSteamId2);
				PrintToServer("SteamId3: %s", sSteamId3);
				PrintToServer("SteamId64: %s", sSteamId64);
				PrintToServer("IP: %s", sIPBuffer2);
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		char query[256];
		g_hDatabase.Format(query, sizeof(query), "SELECT Name, IP, AccountID FROM Players WHERE Name LIKE '%%%s%%' ORDER BY `Players`.`Date` DESC", arg);

		hHistoryAllPack = new DataPack();
		hHistoryAllPack.WriteCell(userid);
		hHistoryAllPack.WriteString(arg);

		g_hDatabase.Query(OnInfoQueryRetry3, query, hHistoryAllPack);
	}

	delete hAllHistory;
}

public void OnHistoryAllQueryRetry3(Database db, DBResultSet results, const char[] sError, DataPack hHistoryAllPack)
{
	char arg[256];
	hHistoryAllPack.Reset();
	int userid = hHistoryAllPack.ReadCell();
	hHistoryAllPack.ReadString(arg, sizeof(arg));
	delete hHistoryAllPack;

	int client = GetClientOfUserId(userid);

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}

	DataPack hAllHistory = new DataPack();
	int iAllHistoryAmount;

	while (results.FetchRow())
	{
		char sNameBuffer1[MAX_NAME_LENGTH];
		char sIPBuffer1[16];
		char sAccountIdBuffer1[32];

		results.FetchString(0, sNameBuffer1, sizeof(sNameBuffer1));
		results.FetchString(1, sIPBuffer1, sizeof(sIPBuffer1));
		results.FetchString(2, sAccountIdBuffer1, sizeof(sAccountIdBuffer1));

		hAllHistory.WriteString(sNameBuffer1);
		hAllHistory.WriteString(sIPBuffer1);
		hAllHistory.WriteString(sAccountIdBuffer1);

		iAllHistoryAmount++;
	}

	if (results.RowCount != 0)
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");

		hAllHistory.Reset();

		for (int i = 0; i < iAllHistoryAmount; i++)
		{
			if (i != 0)
			{	
				if (g_iPrintChat && client)
					CPrintToChat(client, "{green}----------");
				if (g_iPrintConsole && client)
					PrintToConsole(client, "----------");
				if (g_iPrintServer)
					PrintToServer("----------");
			}

			char sNameBuffer2[MAX_NAME_LENGTH];
			char sIPBuffer2[16];
			char sAccountIdBuffer2[32];
			hAllHistory.ReadString(sNameBuffer2, sizeof(sNameBuffer2));
			hAllHistory.ReadString(sIPBuffer2, sizeof(sIPBuffer2));
			hAllHistory.ReadString(sAccountIdBuffer2, sizeof(sAccountIdBuffer2));

			int iAccountId = StringToInt(sAccountIdBuffer2);

			char sSteamId2[32];
			char sSteamId3[32];
			char sSteamId64[64];

			GetSteamId2ByAccountId(iAccountId, sSteamId2, sizeof(sSteamId2));
			GetSteamId3ByAccountId(iAccountId, sSteamId3, sizeof(sSteamId3));
			GetSteamId64ByAccountId(iAccountId, sSteamId64, sizeof(sSteamId64));

			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{default}Name: {olive}%s", sNameBuffer2);
				CPrintToChat(client, "{default}SteamId2: {olive}%s", sSteamId2);
				CPrintToChat(client, "{default}SteamId3: {olive}%s", sSteamId3);
				CPrintToChat(client, "{default}SteamId64: {olive}%s", sSteamId64);
				CPrintToChat(client, "{default}IP: {olive}%s", sIPBuffer2);
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "Name: %s", sNameBuffer2);
				PrintToConsole(client, "SteamId2: %s", sSteamId2);
				PrintToConsole(client, "SteamId3: %s", sSteamId3);
				PrintToConsole(client, "SteamId64: %s", sSteamId64);
				PrintToConsole(client, "IP: %s", sIPBuffer2);
			}

			if (g_iPrintServer)
			{
				PrintToServer("Name: %s", sNameBuffer2);
				PrintToServer("SteamId2: %s", sSteamId2);
				PrintToServer("SteamId3: %s", sSteamId3);
				PrintToServer("SteamId64: %s", sSteamId64);
				PrintToServer("IP: %s", sIPBuffer2);
			}
		}

		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}]{blue}========================={default}[{green}!{default}]");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!]=========================[!]");
		if (g_iPrintServer)
			PrintToServer("[!]=========================[!]");
	}
	else
	{
		if (g_iPrintChat && client)
			CPrintToChat(client, "[{green}!{default}] {red}No player found");
		if (g_iPrintConsole && client)
			PrintToConsole(client, "[!] No player found");
		if (g_iPrintServer)
			PrintToServer("[!] No player found");
	}

	delete hAllHistory;
}

////////////////////////////////////////////////////////////////

public void SQL_CreateAndInsertQuery(Database db, DBResultSet results, const char[] sError, any data)
{
	if(db == null || results == null || sError[0] != '\0')
	{
		LogError("Database query failure: %s", sError);
		return;
	}
}

////////////////////////////////////////////////////////////////
// SteamID Classification Functions
////////////////////////////////////////////////////////////////

int GetArgType(const char[] arg)
{
	if (StrContains(arg, "STEAM_") != -1)
		return Arg_Steam2ID;

	if (StrContains(arg, "U:1:") != -1)
		 return Arg_Steam3ID;

	if (IsIP(arg))
		return Arg_IP;

	if (StringToInt(arg))
		return strlen(arg) > 16 ? Arg_Steam64ID : Arg_Steam32ID;

	return Arg_Name;
}

bool IsIP(const char[] arg)
{
	int iDots;

	for (int i = 0; i < strlen(arg); i++)
	{
		if (arg[i] == '.')
			iDots++;
		if (!IsCharNumeric(arg[i]) && arg[i] != '.')
			return false;
	}

	if (iDots == 3)
		return true;

	return false;
}

////////////////////////////////////////////////////////////////
// SteamID Convert Functions
////////////////////////////////////////////////////////////////

stock int GetAccountIdByAny(int client, const char[] arg, int iArgType)
{
	int iAccountId;

	if (GetArgType(arg) == Arg_Steam2ID)
	{
		iAccountId = GetAccountIdBySteamId2(arg);

		if (arg[7] == '\0')
		{
			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{blue}[{default}!{blue}] {default}If you are trying to use a {blue}SteamID2\n"
					..."{blue}[{default}!{blue}] {default}(i.e.: {olive}STEAM_0:1:191972089{default})\n"
					..."{blue}[{default}!{blue}] {default}Don't forget the {green}\"quotes\"{default}!");
			}
			
			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "[!] If you are trying to use a SteamID2\n"
					..."[!] (i.e.: STEAM_0:1:191972089)\n"
					..."[!] Don't forget the \"quotes\"!");
			}

			if (g_iPrintServer)
			{
				PrintToServer("[!] If you are trying to use a SteamID2\n"
					..."[!] (i.e.: STEAM_0:1:191972089)\n"
					..."[!] Don't forget the \"quotes\"!");
			}
		}

		return iAccountId;
	}
	else if (GetArgType(arg) == Arg_Steam3ID)
	{
		iAccountId = GetAccountIdBySteamId3(arg);

		return iAccountId;
	}
	else if (GetArgType(arg) == Arg_Steam32ID)
	{
		iAccountId = StringToInt(arg);

		return iAccountId;
	}
	else if (GetArgType(arg) == Arg_Steam64ID)
	{
		iAccountId = GetAccountIdBySteamId64(arg);

		return iAccountId;
	}
	else if (GetArgType(arg) == Arg_Name)
	{
		if (arg[0] == 'U' && arg[1] == '\0')
		{
			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{blue}[{default}!{blue}] {default}If you are trying to use a {blue}SteamID3\n"
					..."{blue}[{default}!{blue}] {default}(i.e.: {olive}U:1:383944179{default})\n"
					..."{blue}[{default}!{blue}] {default}Don't forget the {green}\"quotes\"{default}!");
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "[!] If you are trying to use a SteamID3\n"
					..."[!] (i.e.: U:1:383944179)\n"
					..."[!] Don't forget the \"quotes\"!");
			}

			if (g_iPrintServer)
			{
				PrintToServer("[!] If you are trying to use a SteamID3\n"
					..."[!] (i.e.: U:1:383944179)\n"
					..."[!] Don't forget the \"quotes\"!");
			}
		}
		else if (arg[0] == '[' && arg[1] == 'U' && arg[2] == '\0')
		{
			if (g_iPrintChat && client)
			{
				CPrintToChat(client, "{blue}[{default}!{blue}] {default}If you are trying to use a {blue}SteamID3\n"
					..."{blue}[{default}!{blue}] {default}(i.e.: {olive}[U:1:383944179]{default})\n"
					..."{blue}[{default}!{blue}] {default}Don't forget the {green}\"quotes\"{default}!");
			}

			if (g_iPrintConsole && client)
			{
				PrintToConsole(client, "[!] If you are trying to use a SteamID3\n"
					..."[!] (i.e.: [U:1:383944179])\n"
					..."[!] Don't forget the \"quotes\"!");
			}

			if (g_iPrintServer)
			{
				PrintToServer("[!] If you are trying to use a SteamID3\n"
					..."[!] (i.e.: [U:1:383944179])\n"
					..."[!] Don't forget the \"quotes\"!");
			}
		}

		return 0;
	}

	return 0;
}

stock int GetAccountIdBySteamId2(const char[] sSteamID2)
{
	char sBuffer[3][12];
	ExplodeString(sSteamID2, ":", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));

	return StringToInt(sBuffer[1]) + (StringToInt(sBuffer[2]) << 1);
}

stock int GetAccountIdBySteamId3(const char[] sSteamID3)
{
	char sBuffer[19];
	strcopy(sBuffer, sizeof(sBuffer), sSteamID3);
	
	int iBuffer = strlen(sBuffer) - 1;

	if (sBuffer[iBuffer] == ']')
		sBuffer[iBuffer] = '\0';

	return StringToInt(sBuffer[FindCharInString(sBuffer, ':', true) + 1]);
}

stock int GetAccountIdBySteamId64(const char[] sSteam64) 
{
	static const char sBase[] = "76561197960265728";
	int iBorrow = 0;
	char sAccount[17];
	int iTemp;

	for (int i = 16; i >= 0; --i)
	{
		if (iBorrow > 0)
		{
			iTemp = (sSteam64[i] - '0') - 1;

			if (iTemp >= (sBase[i] - '0'))
			{
				iBorrow = 0;
				sAccount[i] = (iTemp - ((sBase[i]) - '0')) + '0';
			}
			else
			{
				iBorrow = 1; 
				sAccount[i] = ((iTemp + 10) - (sBase[i] - '0')) + '0';
			}
		}
		else
		{
			if ((sSteam64[i] - '0') >= (sBase[i] - '0'))
			{
				iBorrow = 0;
				sAccount[i] = ((sSteam64[i] - '0') - (sBase[i] - '0')) + '0';
			}
			else
			{
				iBorrow = 1; 
				sAccount[i] = (((sSteam64[i] - '0') + 10) - (sBase[i] - '0') + '0');
			}
		}
	}

	return StringToInt(sAccount);
}

stock Action GetSteamId2ByAccountId(int iAccountId, char[] sSteamId2, int isizeof)
{
	EngineVersion e = GetEngineVersion();
	int iEngine = (e == Engine_Left4Dead || e == Engine_Left4Dead2 || Engine_CSGO);
	FormatEx(sSteamId2, isizeof, "STEAM_%i:%i:%i", iEngine, iAccountId % 2, iAccountId / 2);
}

stock Action GetSteamId3ByAccountId(int iAccountId, char[] sSteamId3, int isizeof)
{
	FormatEx(sSteamId3, isizeof, "[U:1:%i]", iAccountId);
}

stock void GetSteamId64ByAccountId(const int iAccountId, char[] sSteamId64, int isizeof)
{
	strcopy(sSteamId64, isizeof, "76561");

	char sBuffer[11];
	FormatEx(sBuffer, sizeof(sBuffer), "%010u", iAccountId);
	FormatEx(sSteamId64[5], isizeof - 5, "%i", 1979 + 10 * (sBuffer[0] - '0') + sBuffer[1] - '0');
	
	int iBuffer = StringToInt(sBuffer[2]) + 60265728;
	
	if (iBuffer > 100000000)
	{
		iBuffer -= 100000000;
		++sSteamId64[8];

		for (int i = 8; i > 4; --i)
		{
			if ( sSteamId64[i] > '9')
			{
				sSteamId64[i] = '0';
				++sSteamId64[i-1]; 
			}
			else
			{ 
				break;
			} 
		} 
	}

	FormatEx(sSteamId64[9], isizeof - 9, "%i", iBuffer);
}

////////////////////////////////////////////////////////////////