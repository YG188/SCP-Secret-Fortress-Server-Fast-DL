#pragma semicolon 1
#pragma newdecls required

static const char TFClassNames[][] =
{
	"civilian",
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavy",
	"pyro",
	"spy",
	"engineer"
};

#define FILE_PATH	"configs/scp_sf/"
#define FILE_MAPS	"maps"
#define FILE_REACTIONS	"reactions.cfg"
#define FILE_WEAPONS	"weapons.cfg"
#define FILE_GAMEMODE	"gamemode.cfg"
#define FILE_CLASSES	"classes.cfg"
#define SOUNDPICKUP	"items/pumpkin_pickup.wav"

static KeyValues Reactions;

void Config_Setup()
{
	char mapname[64], buffer[PLATFORM_MAX_PATH];
	GetCurrentMap(mapname, sizeof(mapname));
	KeyValues map;

	BuildPath(Path_SM, buffer, sizeof(buffer), "%s%s", FILE_PATH, FILE_MAPS);
	DirectoryListing dir = OpenDirectory(buffer);
	if(dir != INVALID_HANDLE)
	{
		FileType file;
		char filename[68];
		while(dir.GetNext(filename, sizeof(filename), file))
		{
			if(file != FileType_File)
				continue;

			if(SplitString(filename, ".cfg", filename, sizeof(filename)) == -1)
				continue;
				
			if(StrContains(mapname, filename))
				continue;

			map = new KeyValues("Map");
			Format(buffer, sizeof(buffer), "%s/%s.cfg", buffer, filename);
			if(!map.ImportFromFile(buffer))
				LogError("[Config] Found '%s' but was unable to read", buffer);

			break;
		}
		delete dir;
	}
	else
	{
		LogError("[Config] Directory '%s' does not exist", buffer);
	}


	KeyValues main = new KeyValues("Gamemode");
	BuildPath(Path_SM, buffer, sizeof(buffer), "%s%s", FILE_PATH, FILE_GAMEMODE);
	if(!main.ImportFromFile(buffer) && (!map || !map.JumpToKey("Gamemode")))
		SetFailState("Failed to read '%s'", buffer);

	ArrayList list = Gamemode_Setup(main, map);
	delete main;


	main = new KeyValues("Classes");
	BuildPath(Path_SM, buffer, sizeof(buffer), "%s%s", FILE_PATH, FILE_CLASSES);
	if(!main.ImportFromFile(buffer) && (!map || !map.JumpToKey("Classes")))
		SetFailState("Failed to read '%s'", buffer);

	Classes_Setup(main, map, list);
	delete main;
	if(list)
		delete list;


	main = new KeyValues("Weapons");
	BuildPath(Path_SM, buffer, sizeof(buffer), "%s%s", FILE_PATH, FILE_WEAPONS);
	if(!main.ImportFromFile(buffer) && (!map || !map.JumpToKey("Weapons")))
		SetFailState("Failed to read '%s'", buffer);

	Items_Setup(main, map);
	delete main;


	if(Reactions)
		delete Reactions;

	Reactions = new KeyValues("Reactions");
	if(map)
	{
		map.Rewind();
		if(map.JumpToKey("Reactions"))
		{
			Reactions.Import(map);
			delete map;
			return;
		}

		delete map;
	}

	BuildPath(Path_SM, buffer, sizeof(buffer), "%s%s", FILE_PATH, FILE_REACTIONS);
	if(!Reactions.ImportFromFile(buffer))
		SetFailState("Failed to read '%s'", buffer);

	Reactions.ImportFromFile(buffer);
	
	Config_PrecacheReactions(Reactions);

	// I have no clue what's the best place to put this in
	// For now I'll just put it here, if more sounds are needed in this style then it should be moved somewhere else
	PrecacheSound("replay/cameracontrolerror.wav", true);
	PrecacheSound("common/wpn_denyselect.wav", true);
	PrecacheSound("ui/item_light_gun_drop.wav", true);
	PrecacheSound("ui/item_store_add_to_cart.wav", true);	
	PrecacheSound("physics/metal/metal_grate_impact_hard1.wav", true);
	PrecacheSound("physics/metal/metal_grate_impact_hard2.wav", true);
	PrecacheSound("physics/metal/metal_grate_impact_hard3.wav", true);
}

void Config_PrecacheReactions(KeyValues kv)
{
	char buffer[PLATFORM_MAX_PATH];
	
	do
	{
		if (kv.GotoFirstSubKey(false))
		{
			// recursively go down
			Config_PrecacheReactions(kv);
			kv.GoBack();
		}
		else
		{
			if (kv.GetDataType(NULL_STRING) != KvData_None)
			{
				kv.GetString(NULL_STRING, buffer, sizeof(buffer));
				if (buffer[0])
				{
					PrecacheSound(buffer, true);
				}
			}
		}
	} 
	while (kv.GotoNextKey(false));	
}

void Config_DoReaction(int client, const char[] name)
{
	Reactions.Rewind();
	if(Reactions.JumpToKey(name))
	{
		if(Reactions.JumpToKey(TFClassNames[TF2_GetPlayerClass(client)]))
		{
			static char buffer[PLATFORM_MAX_PATH];
			int amount;
			do
			{
				IntToString(++amount, buffer, sizeof(buffer));
				Reactions.GetString(buffer, buffer, sizeof(buffer));
			} while(buffer[0]);

			char buffer2[PLATFORM_MAX_PATH];
			if(amount > 1)
			{
				IntToString(GetRandomInt(1, amount-1), buffer, sizeof(buffer));
				Reactions.GetString(buffer, buffer, sizeof(buffer));
				strcopy(buffer2, sizeof(buffer2), buffer);
			}

			switch(Forward_OnReactionPre(client, name, buffer2))
			{
				case Plugin_Changed:
				{
					strcopy(buffer, sizeof(buffer), buffer2);
				}
				case Plugin_Handled, Plugin_Stop:
				{
					return;
				}
				default:
				{
					if(amount < 2)
						return;
				}
			}

			PrecacheSound(buffer, true);
			EmitSoundToAll(buffer, client, SNDCHAN_VOICE, 95);
		}
	}
}