# Player Record

### Save information about players in each connection

- Save AccountID, name and IP in each connection
- Save AccountID, name and IP in a name change
- If the AccountID. name and IP are the same as a previous save, only the date will be updated
- Useful admin commands to view info about players giving an AccountID, name or IP

## Info Commands
Command | Description
--------| -----------
**sm_playerinfo** | Shows names, all types of SteamID and IPs seen with a given SteamID of any type, IP or name
**sm_nameinfo** | Shows names, all types of SteamID and IPs seen with a given name
**sm_ipinfo** | Shows names, all types of SteamID and IPs of all players who have joined from the given IP
**sm_steamid2info** | Shows last name, all types of SteamID and last seen IP explicitly searching with a SteamID2
**sm_steamid3info** | Shows last name, all types of SteamID and last seen IP explicitly searching with a SteamID3
**sm_steamid64info** | Shows last name, all types of SteamID and last seen IP explicitly searching with a SteamID64

## History Commands
Command | Description
--------| -----------
**sm_playerall** | Shows a history of all names, all types of SteamID and all IPs of a given SteamID, IP or name
**sm_namenames** | Shows a history of all names that a player had searching with one of his names
**sm_steamid2names** | Shows a history of all names a player had searching with a SteamID2
**sm_steamid3names** | Shows a history of all names a player had searching with a SteamID3
**sm_steamid64names** | Shows a history of all names a player had searching with a SteamID64
**sm_nameips** | Shows a history of all IPs connected with the given name
**sm_steamid2ips** | Shows a history of all IPs from where a SteamID2 was connected
**sm_steamid3ips** | Shows a history of all IPs from where a SteamID3 was connected
**sm_steamid64ips** | Shows a history of all IPs from where a SteamID64 was connected
**sm_ipall** | Shows a history of all types of SteamID and their respective names seen on an IP

## Cvars
Cvar | Description
--------| -----------
**db_playerrecord_printchat** | Set whether the command response should be seen in the chat
**db_playerrecord_printonsole** | Set whether the command response should be seen in the client console
**db_playerrecord_printserver** | Set whether the command response should be seen in the server console

# How to install
- Install MySQL with `sudo apt-get install mysql-server`
- Create a user and a database, and make sure it's remotely accessible
- Run this command on MySQL `SET GLOBAL sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));`
- Add this on **databases.cfg**, located in **addons/sourcemod/configs** (edit the values with *)
```
"PlayerRecord"
	{
		"driver"			"mysql"
		"host"				"database_host*"
		"database"			"database_name*"
		"user"				"mysql_user*"
		"pass"				"user_password*"
	}
```
- Put **db_player_record.smx** in your plugins folder and make sure it's always loaded
