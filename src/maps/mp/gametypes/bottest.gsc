/*
    Zombies, Version 5, Revision 13
    Copyright (C) 2016, DJ Hepburn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
    Team Deathmatch
    Objective:  Score points for your team by eliminating players on the opposing team
    Map ends:   When one team reaches the score limit, or time limit is reached
    Respawning: No wait / Near teammates

    Level requirements
    ------------------
        Spawnpoints:
            classname       mp_teamdeathmatch_spawn
            All players spawn from these. The spawnpoint chosen is dependent on the current locations of teammates and enemies
            at the time of spawn. Players generally spawn behind their teammates relative to the direction of enemies. 

        Spectator Spawnpoints:
            classname       mp_teamdeathmatch_intermission
            Spectators spawn from these and intermission is viewed from these positions.
            Atleast one is required, any more and they are randomly chosen between.

    Level script requirements
    -------------------------
        Team Definitions:
            game["allies"] = "american";
            game["axis"] = "german";
            This sets the nationalities of the teams. Allies can be american, british, or russian. Axis can be german.
    
        If using minefields or exploders:
            maps\mp\_load::main();
        
    Optional level script settings
    ------------------------------
        Soldier Type and Variation:
            game["american_soldiertype"] = "airborne";
            game["american_soldiervariation"] = "normal";
            game["german_soldiertype"] = "wehrmacht";
            game["german_soldiervariation"] = "normal";
            This sets what models are used for each nationality on a particular map.
            
            Valid settings:
                american_soldiertype        airborne
                american_soldiervariation   normal, winter
                
                british_soldiertype     airborne, commando
                british_soldiervariation    normal, winter
                
                russian_soldiertype     conscript, veteran
                russian_soldiervariation    normal, winter
                
                german_soldiertype      waffen, wehrmacht, fallschirmjagercamo, fallschirmjagergrey, kriegsmarine
                german_soldiervariation     normal, winter

        Layout Image:
            game["layoutimage"] = "yourlevelname";
            This sets the image that is displayed when players use the "View Map" button in game.
            Create an overhead image of your map and name it "hud@layout_yourlevelname".
            Then move it to main\levelshots\layouts. This is generally done by taking a screenshot in the game.
            Use the outsideMapEnts console command to keep models such as trees from vanishing when noclipping outside of the map.
*/

/*QUAKED mp_teamdeathmatch_spawn (0.0 0.0 1.0) (-16 -16 0) (16 16 72)
Players spawn away from enemies and near their team at one of these positions.
*/

/*QUAKED mp_teamdeathmatch_intermission (1.0 0.0 1.0) (-16 -16 -16) (16 16 16)
Intermission is randomly viewed from one of these positions.
Spectators spawn randomly at one of these positions.
*/

main()
{
    level.callbackStartGameType = ::Callback_StartGameType;
    level.callbackPlayerConnect = ::Callback_PlayerConnect;
    level.callbackPlayerDisconnect = ::Callback_PlayerDisconnect;
    level.callbackPlayerDamage = ::Callback_PlayerDamage;
    level.callbackPlayerKilled = ::Callback_PlayerKilled;

    maps\mp\gametypes\_callbacksetup::SetupCallbacks();
    
    allowed[0] = "tdm";
    maps\mp\gametypes\_gameobjects::main(allowed);
    
    if(getcvar("scr_tdm_timelimit") == "")      // Time limit per map
        setcvar("scr_tdm_timelimit", "30");
    else if(getcvarfloat("scr_tdm_timelimit") > 1440)
        setcvar("scr_tdm_timelimit", "1440");
    level.timelimit = getcvarfloat("scr_tdm_timelimit");

    if(getcvar("scr_tdm_scorelimit") == "")     // Score limit per map
        setcvar("scr_tdm_scorelimit", "100");
    level.scorelimit = getcvarint("scr_tdm_scorelimit");

    if(getcvar("scr_forcerespawn") == "")       // Force respawning
        setcvar("scr_forcerespawn", "0");

    if(getcvar("scr_friendlyfire") == "")       // Friendly fire
        setcvar("scr_friendlyfire", "0");

    if(getcvar("scr_drawfriend") == "")     // Draws a team icon over teammates
        setcvar("scr_drawfriend", "0");
    level.drawfriend = getcvarint("scr_drawfriend");

    if(getcvar("g_allowvote") == "")
        setcvar("g_allowvote", "1");
    level.allowvote = getcvarint("g_allowvote");
    setcvar("scr_allow_vote", level.allowvote);

    if(!isdefined(game["state"]))
        game["state"] = "playing";

    level.mapended = false;
    level.healthqueue = [];
    level.healthqueuecurrent = 0;
    
    spawnpointname = "mp_teamdeathmatch_spawn";
    spawnpoints = getentarray(spawnpointname, "classname");

    if(spawnpoints.size > 0)
    {
        for(i = 0; i < spawnpoints.size; i++)
            spawnpoints[i] placeSpawnpoint();
    }
    else
        maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");
        
    setarchive(true);

    zombies\debug::init();
    zombies\precache::init();
    zombies\skins::init();
    botlib\main::init();
}

Callback_StartGameType()
{
    // defaults if not defined in level script
    game[ "allies" ] = "british";
    game[ "axis" ] = "german";

    if(!isdefined(game["layoutimage"]))
        game["layoutimage"] = "default";
    layoutname = "levelshots/layouts/hud@layout_" + game["layoutimage"];
    precacheShader(layoutname);
    setcvar("scr_layoutimage", layoutname);
    makeCvarServerInfo("scr_layoutimage", "");
   
    game[ "menu_team" ] =               "team_" + game["allies"] + game["axis"];
    game[ "menu_weapon_allies" ] =      "weapon_" + game["allies"];
    game[ "menu_weapon_axis" ] =        "weapon_americangerman";
    game[ "menu_viewmap" ] =            "viewmap";
    game[ "menu_callvote" ] =           "callvote";
    game[ "menu_quickcommands" ] =      "quickcommands";
    game[ "menu_quickstatements" ] =    "quickstatements";
    game[ "menu_quickresponses" ] =     "quickresponses";
    game[ "headicon_allies" ] =         "gfx/hud/headicon@allies.tga";
    game[ "headicon_axis" ] =           "gfx/hud/headicon@axis.tga";

    precacheMenu( "clientcmd" );

    precacheString(&"MPSCRIPT_PRESS_ACTIVATE_TO_RESPAWN");
    precacheString(&"MPSCRIPT_KILLCAM");

    precacheMenu(game["menu_team"]);
    precacheMenu(game["menu_weapon_allies"]);
    precacheMenu(game["menu_weapon_axis"]);
    precacheMenu(game["menu_viewmap"]);
    precacheMenu(game["menu_callvote"]);
    precacheMenu(game["menu_quickcommands"]);
    precacheMenu(game["menu_quickstatements"]);
    precacheMenu(game["menu_quickresponses"]);

    precacheShader("black");
    precacheShader("hudScoreboard_mp");
    precacheShader("gfx/hud/hud@mpflag_spectator.tga");
    precacheStatusIcon("gfx/hud/hud@status_dead.tga");
    precacheStatusIcon("gfx/hud/hud@status_connecting.tga");
    precacheHeadIcon(game["headicon_allies"]);
    precacheHeadIcon(game["headicon_axis"]);
    precacheItem("item_health");

    maps\mp\gametypes\_teams::modeltype();
    maps\mp\gametypes\_teams::precache();
    maps\mp\gametypes\_teams::scoreboard();
    maps\mp\gametypes\_teams::initGlobalCvars();
    maps\mp\gametypes\_teams::restrictPlacedWeapons();

    setClientNameMode("auto_change");
    
    thread startGame();
    //thread addBotClients(); // For development testing
    thread updateScriptCvars();

    thread botlib\main::main();
}

Callback_PlayerConnect()
{
    if ( self isBot() ) {
        self [[ level.bot_connect ]]();
        return;
    }

    self.statusicon = "gfx/hud/hud@status_connecting.tga";
    self waittill("begin");
    self.statusicon = "";

    iprintln(&"MPSCRIPT_CONNECTED", self);

    lpselfnum = self getEntityNumber();
    logPrint("J;" + lpselfnum + ";" + self.name + "\n");

    if(game["state"] == "intermission")
    {
        spawnIntermission();
        return;
    }
    
    level endon("intermission");

    if(isdefined(self.pers["team"]) && self.pers["team"] != "spectator")
    {
        self setClientCvar("scr_showweapontab", "1");

        if(self.pers["team"] == "allies")
        {
            self.sessionteam = "allies";
            self setClientCvar("g_scriptMainMenu", game["menu_weapon_allies"]);
        }
        else
        {
            self.sessionteam = "axis";
            self setClientCvar("g_scriptMainMenu", game["menu_weapon_axis"]);
        }
            
        if(isdefined(self.pers["weapon"]))
            spawnPlayer();
        else
        {
            spawnSpectator();

            if(self.pers["team"] == "allies")
                self openMenu(game["menu_weapon_allies"]);
            else
                self openMenu(game["menu_weapon_axis"]);
        }
    }
    else
    {
        self setClientCvar("g_scriptMainMenu", game["menu_team"]);
        self setClientCvar("scr_showweapontab", "0");
        
        if(!isdefined(self.pers["team"]))
            self openMenu(game["menu_team"]);

        self.pers["team"] = "spectator";
        self.sessionteam = "spectator";

        spawnSpectator();
    }

    for(;;)
    {
        self waittill("menuresponse", menu, response);
        
        if(response == "open" || response == "close")
            continue;

        if(menu == game["menu_team"])
        {
            switch(response)
            {
            case "allies":
            case "axis":
            case "autoassign":
                if(response == "autoassign")
                {
                    numonteam["allies"] = 0;
                    numonteam["axis"] = 0;

                    players = getentarray("player", "classname");
                    for(i = 0; i < players.size; i++)
                    {
                        player = players[i];
                    
                        if(!isdefined(player.pers["team"]) || player.pers["team"] == "spectator" || player == self)
                            continue;
            
                        numonteam[player.pers["team"]]++;
                    }
                    
                    // if teams are equal return the team with the lowest score
                    if(numonteam["allies"] == numonteam["axis"])
                    {
                        if(getTeamScore("allies") == getTeamScore("axis"))
                        {
                            teams[0] = "allies";
                            teams[1] = "axis";
                            response = teams[randomInt(2)];
                        }
                        else if(getTeamScore("allies") < getTeamScore("axis"))
                            response = "allies";
                        else
                            response = "axis";
                    }
                    else if(numonteam["allies"] < numonteam["axis"])
                        response = "allies";
                    else
                        response = "axis";
                }
                
                if(response == self.pers["team"] && self.sessionstate == "playing")
                    break;

                if(response != self.pers["team"] && self.sessionstate == "playing")
                    self suicide();

                self notify("end_respawn");

                self.pers["team"] = response;
                self.pers["weapon"] = undefined;
                self.pers["savedmodel"] = undefined;

                self setClientCvar("scr_showweapontab", "1");

                if(self.pers["team"] == "allies")
                {
                    self setClientCvar("g_scriptMainMenu", game["menu_weapon_allies"]);
                    self openMenu(game["menu_weapon_allies"]);
                }
                else
                {
                    self setClientCvar("g_scriptMainMenu", game["menu_weapon_axis"]);
                    self openMenu(game["menu_weapon_axis"]);
                }
                break;

            case "spectator":
                if(self.pers["team"] != "spectator")
                {
                    self.pers["team"] = "spectator";
                    self.pers["weapon"] = undefined;
                    self.pers["savedmodel"] = undefined;
                    
                    self.sessionteam = "spectator";
                    self setClientCvar("g_scriptMainMenu", game["menu_team"]);
                    self setClientCvar("scr_showweapontab", "0");
                    spawnSpectator();
                }
                break;

            case "weapon":
                if(self.pers["team"] == "allies")
                    self openMenu(game["menu_weapon_allies"]);
                else if(self.pers["team"] == "axis")
                    self openMenu(game["menu_weapon_axis"]);
                break;
                
            case "viewmap":
                self openMenu(game["menu_viewmap"]);
                break;

            case "callvote":
                self openMenu(game["menu_callvote"]);
                break;
            }
        }       
        else if(menu == game["menu_weapon_allies"] || menu == game["menu_weapon_axis"])
        {
            if(response == "team")
            {
                self openMenu(game["menu_team"]);
                continue;
            }
            else if(response == "viewmap")
            {
                self openMenu(game["menu_viewmap"]);
                continue;
            }
            else if(response == "callvote")
            {
                self openMenu(game["menu_callvote"]);
                continue;
            }
            
            if(!isdefined(self.pers["team"]) || (self.pers["team"] != "allies" && self.pers["team"] != "axis"))
                continue;

            weapon = self maps\mp\gametypes\_teams::restrict(response);

            if(weapon == "restricted")
            {
                self openMenu(menu);
                continue;
            }
            
            if(isdefined(self.pers["weapon"]) && self.pers["weapon"] == weapon)
                continue;
            
            if(!isdefined(self.pers["weapon"]))
            {
                self.pers["weapon"] = weapon;
                spawnPlayer();
                self thread printJoinedTeam(self.pers["team"]);
            }
            else
            {
                self.pers["weapon"] = weapon;

                weaponname = maps\mp\gametypes\_teams::getWeaponName(self.pers["weapon"]);
                
                if(maps\mp\gametypes\_teams::useAn(self.pers["weapon"]))
                    self iprintln(&"MPSCRIPT_YOU_WILL_RESPAWN_WITH_AN", weaponname);
                else
                    self iprintln(&"MPSCRIPT_YOU_WILL_RESPAWN_WITH_A", weaponname);
            }
        }
        else if(menu == game["menu_viewmap"])
        {
            switch(response)
            {
            case "team":
                self openMenu(game["menu_team"]);
                break;
                
            case "weapon":
                if(self.pers["team"] == "allies")
                    self openMenu(game["menu_weapon_allies"]);
                else if(self.pers["team"] == "axis")
                    self openMenu(game["menu_weapon_axis"]);
                break;

            case "callvote":
                self openMenu(game["menu_callvote"]);
                break;
            }
        }
        else if(menu == game["menu_callvote"])
        {
            switch(response)
            {
            case "team":
                self openMenu(game["menu_team"]);
                break;
                
            case "weapon":
                if(self.pers["team"] == "allies")
                    self openMenu(game["menu_weapon_allies"]);
                else if(self.pers["team"] == "axis")
                    self openMenu(game["menu_weapon_axis"]);
                break;

            case "viewmap":
                self openMenu(game["menu_viewmap"]);
                break;
            }
        }
        else if(menu == game["menu_quickcommands"])
            maps\mp\gametypes\_teams::quickcommands(response);
        else if(menu == game["menu_quickstatements"])
            maps\mp\gametypes\_teams::quickstatements(response);
        else if(menu == game["menu_quickresponses"])
            maps\mp\gametypes\_teams::quickresponses(response);
    }
}

Callback_PlayerDisconnect()
{
    if ( self isBot() ) {
        self [[ level.bot_disconnect ]]();
        return;
    }

    iprintln(&"MPSCRIPT_DISCONNECTED", self);

    lpselfnum = self getEntityNumber();
    logPrint("Q;" + lpselfnum + ";" + self.name + "\n");
}

Callback_PlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc)
{
    if ( self isBot() ) {
        self [[ level.bot_damage ]]( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc );
        return;
    }

    if(self.sessionteam == "spectator")
        return;

    // Don't do knockback if the damage direction was not specified
    if(!isDefined(vDir))
        iDFlags |= level.iDFLAGS_NO_KNOCKBACK;

    // check for completely getting out of the damage
    if(!(iDFlags & level.iDFLAGS_NO_PROTECTION))
    {
        if(isPlayer(eAttacker) && (self != eAttacker) && (self.pers["team"] == eAttacker.pers["team"]))
        {
            if(getCvarInt("scr_friendlyfire") <= 0)
                return;

            if(getCvarInt("scr_friendlyfire") == 2)
                reflect = true;
        }
    }

    // Apply the damage to the player
    if(!isdefined(reflect))
    {
        // Make sure at least one point of damage is done
        if(iDamage < 1)
            iDamage = 1;

        self finishPlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc);
    }
    else
    {
        eAttacker.reflectdamage = true;
        
        iDamage = iDamage * .5;

        // Make sure at least one point of damage is done
        if(iDamage < 1)
            iDamage = 1;

        eAttacker finishPlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc);
        eAttacker.reflectdamage = undefined;
    }

    // Do debug print if it's enabled
    if(getCvarInt("g_debugDamage"))
    {
        println("client:" + self getEntityNumber() + " health:" + self.health +
            " damage:" + iDamage + " hitLoc:" + sHitLoc);
    }

    if(self.sessionstate != "dead")
    {
        lpselfnum = self getEntityNumber();
        lpselfname = self.name;
        lpselfteam = self.pers["team"];
        lpattackerteam = "";

        if(isPlayer(eAttacker))
        {
            lpattacknum = eAttacker getEntityNumber();
            lpattackname = eAttacker.name;
            lpattackerteam = eAttacker.pers["team"];
        }
        else
        {
            lpattacknum = -1;
            lpattackname = "";
            lpattackerteam = "world";
        }

        if(isdefined(reflect)) 
        {  
            lpattacknum = lpselfnum;
            lpattackname = lpselfname;
            lpattackerteam = lpattackerteam;
        }

        logPrint("D;" + lpselfnum + ";" + lpselfteam + ";" + lpselfname + ";" + lpattacknum + ";" + lpattackerteam + ";" + lpattackname + ";" + sWeapon + ";" + iDamage + ";" + sMeansOfDeath + ";" + sHitLoc + "\n");
    }
}

Callback_PlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc)
{
    if ( self isBot() ) {
        self [[ level.bot_killed ]]( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc );
        return;
    }

    self endon("spawned");
    
    if(self.sessionteam == "spectator")
        return;

    // If the player was killed by a head shot, let players know it was a head shot kill
    if(sHitLoc == "head" && sMeansOfDeath != "MOD_MELEE")
        sMeansOfDeath = "MOD_HEAD_SHOT";
        
    // send out an obituary message to all clients about the kill
    obituary(self, attacker, sWeapon, sMeansOfDeath);
    
    self.sessionstate = "dead";
    self.statusicon = "gfx/hud/hud@status_dead.tga";
    self.headicon = "";
    self.deaths++;

    lpselfnum = self getEntityNumber();
    lpselfname = self.name;
    lpselfteam = self.pers["team"];
    lpattackerteam = "";

    attackerNum = -1;
    if(isPlayer(attacker))
    {
        if(attacker == self) // killed himself
        {
            doKillcam = false;

            attacker.score--;
            
            if(isdefined(attacker.reflectdamage))
                clientAnnouncement(attacker, &"MPSCRIPT_FRIENDLY_FIRE_WILL_NOT"); 
        }
        else
        {
            attackerNum = attacker getEntityNumber();
            doKillcam = true;

            if(self.pers["team"] == attacker.pers["team"]) // killed by a friendly
                attacker.score--;
            else
            {
                attacker.score++;

                teamscore = getTeamScore(attacker.pers["team"]);
                teamscore++;
                setTeamScore(attacker.pers["team"], teamscore);
            
                checkScoreLimit();
            }
        }

        lpattacknum = attacker getEntityNumber();
        lpattackname = attacker.name;
        lpattackerteam = attacker.pers["team"];
    }
    else // If you weren't killed by a player, you were in the wrong place at the wrong time
    {
        doKillcam = false;
        
        self.score--;

        lpattacknum = -1;
        lpattackname = "";
        lpattackerteam = "world";
    }

    logPrint("K;" + lpselfnum + ";" + lpselfteam + ";" + lpselfname + ";" + lpattacknum + ";" + lpattackerteam + ";" + lpattackname + ";" + sWeapon + ";" + iDamage + ";" + sMeansOfDeath + ";" + sHitLoc + "\n");

    // Stop thread if map ended on this death
    if(level.mapended)
        return;

    // Make the player drop his weapon
    self dropItem(self getcurrentweapon());
    
    // Make the player drop health
    self dropHealth();

    body = self cloneplayer();

    delay = 2;  // Delay the player becoming a spectator till after he's done dying
    wait delay; // ?? Also required for Callback_PlayerKilled to complete before respawn/killcam can execute

    if(getcvarint("scr_forcerespawn") > 0)
        doKillcam = false;

    if(doKillcam)
        self thread killcam(attackerNum, delay);
    else
        self thread respawn();
}

spawnPlayer()
{
    self notify("spawned");
    self notify("end_respawn");
    
    resettimeout();

    self.sessionteam = self.pers["team"];
    self.sessionstate = "playing";
    self.spectatorclient = -1;
    self.archivetime = 0;
    self.reflectdamage = undefined;
        
    spawnpointname = "mp_teamdeathmatch_spawn";
    spawnpoints = getentarray(spawnpointname, "classname");
    spawnpoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_NearTeam(spawnpoints);

    if(isdefined(spawnpoint))
        self spawn(spawnpoint.origin, spawnpoint.angles);
    else
        maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");

    self.statusicon = "";
    self.maxhealth = 100;
    self.health = self.maxhealth;
    
    if(!isdefined(self.pers["savedmodel"]))
        maps\mp\gametypes\_teams::model();
    else
        maps\mp\_utility::loadModel(self.pers["savedmodel"]);

    maps\mp\gametypes\_teams::loadout();
    
    self giveWeapon(self.pers["weapon"]);
    self giveMaxAmmo(self.pers["weapon"]);
    self setSpawnWeapon(self.pers["weapon"]);
    
    if(self.pers["team"] == "allies")
        self setClientCvar("cg_objectiveText", &"TDM_KILL_AXIS_PLAYERS");
    else if(self.pers["team"] == "axis")
        self setClientCvar("cg_objectiveText", &"TDM_KILL_ALLIED_PLAYERS");

    if(level.drawfriend)
    {
        if(self.pers["team"] == "allies")
        {
            self.headicon = game["headicon_allies"];
            self.headiconteam = "allies";
        }
        else
        {
            self.headicon = game["headicon_axis"];
            self.headiconteam = "axis";
        }
    }

    self thread shit();
}

spawnSpectator(origin, angles)
{
    self notify("spawned");
    self notify("end_respawn");

    resettimeout();

    self.sessionstate = "spectator";
    self.spectatorclient = -1;
    self.archivetime = 0;
    self.reflectdamage = undefined;

    if(self.pers["team"] == "spectator")
        self.statusicon = "";
    
    if(isdefined(origin) && isdefined(angles))
        self spawn(origin, angles);
    else
    {
            spawnpointname = "mp_teamdeathmatch_intermission";
        spawnpoints = getentarray(spawnpointname, "classname");
        spawnpoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random(spawnpoints);
    
        if(isdefined(spawnpoint))
            self spawn(spawnpoint.origin, spawnpoint.angles);
        else
            maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");
    }

    self setClientCvar("cg_objectiveText", &"TDM_ALLIES_KILL_AXIS_PLAYERS");
}

spawnIntermission()
{
    self notify("spawned");
    self notify("end_respawn");

    resettimeout();

    self.sessionstate = "intermission";
    self.spectatorclient = -1;
    self.archivetime = 0;
    self.reflectdamage = undefined;

    spawnpointname = "mp_teamdeathmatch_intermission";
    spawnpoints = getentarray(spawnpointname, "classname");
    spawnpoint = maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random(spawnpoints);
    
    if(isdefined(spawnpoint))
        self spawn(spawnpoint.origin, spawnpoint.angles);
    else
        maps\mp\_utility::error("NO " + spawnpointname + " SPAWNPOINTS IN MAP");
}

respawn()
{
    if(!isdefined(self.pers["weapon"]))
        return;

    self endon("end_respawn");
    
    if(getcvarint("scr_forcerespawn") > 0)
    {
        self thread waitForceRespawnTime();
        self thread waitRespawnButton();
        self waittill("respawn");
    }
    else
    {
        self thread waitRespawnButton();
        self waittill("respawn");
    }
    
    self thread spawnPlayer();
}

waitForceRespawnTime()
{
    self endon("end_respawn");
    self endon("respawn");
    
    wait getcvarint("scr_forcerespawn");
    self notify("respawn");
}

waitRespawnButton()
{
    self endon("end_respawn");
    self endon("respawn");
    
    wait 0; // Required or the "respawn" notify could happen before it's waittill has begun

    self.respawntext = newClientHudElem(self);
    self.respawntext.alignX = "center";
    self.respawntext.alignY = "middle";
    self.respawntext.x = 320;
    self.respawntext.y = 70;
    self.respawntext.archived = false;
    self.respawntext setText(&"MPSCRIPT_PRESS_ACTIVATE_TO_RESPAWN");

    thread removeRespawnText();
    thread waitRemoveRespawnText("end_respawn");
    thread waitRemoveRespawnText("respawn");

    while(self useButtonPressed() != true)
        wait .05;
    
    self notify("remove_respawntext");

    self notify("respawn"); 
}

removeRespawnText()
{
    self waittill("remove_respawntext");

    if(isdefined(self.respawntext))
        self.respawntext destroy();
}

waitRemoveRespawnText(message)
{
    self endon("remove_respawntext");

    self waittill(message);
    self notify("remove_respawntext");
}

killcam(attackerNum, delay)
{
    self endon("spawned");

//  previousorigin = self.origin;
//  previousangles = self.angles;
    
    // killcam
    if(attackerNum < 0)
        return;

    self.sessionstate = "spectator";
    self.spectatorclient = attackerNum;
    self.archivetime = delay + 7;

    // wait till the next server frame to allow code a chance to update archivetime if it needs trimming
    wait 0.05;

    if(self.archivetime <= delay)
    {
        self.spectatorclient = -1;
        self.archivetime = 0;
        self.sessionstate = "dead";
    
        self thread respawn();
        return;
    }

    if(!isdefined(self.kc_topbar))
    {
        self.kc_topbar = newClientHudElem(self);
        self.kc_topbar.archived = false;
        self.kc_topbar.x = 0;
        self.kc_topbar.y = 0;
        self.kc_topbar.alpha = 0.5;
        self.kc_topbar setShader("black", 640, 112);
    }

    if(!isdefined(self.kc_bottombar))
    {
        self.kc_bottombar = newClientHudElem(self);
        self.kc_bottombar.archived = false;
        self.kc_bottombar.x = 0;
        self.kc_bottombar.y = 368;
        self.kc_bottombar.alpha = 0.5;
        self.kc_bottombar setShader("black", 640, 112);
    }

    if(!isdefined(self.kc_title))
    {
        self.kc_title = newClientHudElem(self);
        self.kc_title.archived = false;
        self.kc_title.x = 320;
        self.kc_title.y = 40;
        self.kc_title.alignX = "center";
        self.kc_title.alignY = "middle";
        self.kc_title.sort = 1; // force to draw after the bars
        self.kc_title.fontScale = 3.5;
    }
    self.kc_title setText(&"MPSCRIPT_KILLCAM");

    if(!isdefined(self.kc_skiptext))
    {
        self.kc_skiptext = newClientHudElem(self);
        self.kc_skiptext.archived = false;
        self.kc_skiptext.x = 320;
        self.kc_skiptext.y = 70;
        self.kc_skiptext.alignX = "center";
        self.kc_skiptext.alignY = "middle";
        self.kc_skiptext.sort = 1; // force to draw after the bars
    }
    self.kc_skiptext setText(&"MPSCRIPT_PRESS_ACTIVATE_TO_RESPAWN");

    if(!isdefined(self.kc_timer))
    {
        self.kc_timer = newClientHudElem(self);
        self.kc_timer.archived = false;
        self.kc_timer.x = 320;
        self.kc_timer.y = 428;
        self.kc_timer.alignX = "center";
        self.kc_timer.alignY = "middle";
        self.kc_timer.fontScale = 3.5;
        self.kc_timer.sort = 1;
    }
    self.kc_timer setTenthsTimer(self.archivetime - delay);

    self thread spawnedKillcamCleanup();
    self thread waitSkipKillcamButton();
    self thread waitKillcamTime();
    self waittill("end_killcam");

    self removeKillcamElements();

    self.spectatorclient = -1;
    self.archivetime = 0;
    self.sessionstate = "dead";

    //self thread spawnSpectator(previousorigin + (0, 0, 60), previousangles);
    self thread respawn();
}

waitKillcamTime()
{
    self endon("end_killcam");
    
    wait (self.archivetime - 0.05);
    self notify("end_killcam");
}

waitSkipKillcamButton()
{
    self endon("end_killcam");
    
    while(self useButtonPressed())
        wait .05;

    while(!(self useButtonPressed()))
        wait .05;
    
    self notify("end_killcam"); 
}

removeKillcamElements()
{
    if(isdefined(self.kc_topbar))
        self.kc_topbar destroy();
    if(isdefined(self.kc_bottombar))
        self.kc_bottombar destroy();
    if(isdefined(self.kc_title))
        self.kc_title destroy();
    if(isdefined(self.kc_skiptext))
        self.kc_skiptext destroy();
    if(isdefined(self.kc_timer))
        self.kc_timer destroy();
}

spawnedKillcamCleanup()
{
    self endon("end_killcam");

    self waittill("spawned");
    self removeKillcamElements();
}

startGame()
{
    level.starttime = getTime();
    
    if(level.timelimit > 0)
    {
        level.clock = newHudElem();
        level.clock.x = 320;
        level.clock.y = 460;
        level.clock.alignX = "center";
        level.clock.alignY = "middle";
        level.clock.font = "bigfixed";
        level.clock setTimer(level.timelimit * 60);
    }
    
    for(;;)
    {
        checkTimeLimit();
        wait 1;
    }
}

endMap()
{
    game["state"] = "intermission";
    level notify("intermission");
    
    alliedscore = getTeamScore("allies");
    axisscore = getTeamScore("axis");
    
    if(alliedscore == axisscore)
    {
        winningteam = "tie";
        losingteam = "tie";
        text = "MPSCRIPT_THE_GAME_IS_A_TIE";
    }
    else if(alliedscore > axisscore)
    {
        winningteam = "allies";
        losingteam = "axis";
        text = &"MPSCRIPT_ALLIES_WIN";
    }
    else
    {
        winningteam = "axis";
        losingteam = "allies";
        text = &"MPSCRIPT_AXIS_WIN";
    }
    
    if ( (winningteam == "allies") || (winningteam == "axis") )
    {
        winners = "";
        losers = "";
    }
    
    players = getentarray("player", "classname");
    for(i = 0; i < players.size; i++)
    {
        player = players[i];
        if ( (winningteam == "allies") || (winningteam == "axis") )
        {
            if ( (isdefined (player.pers["team"])) && (player.pers["team"] == winningteam) )
                    winners = (winners + ";" + player.name);
            else if ( (isdefined (player.pers["team"])) && (player.pers["team"] == losingteam) )
                    losers = (losers + ";" + player.name);
        }
        player closeMenu();
        player setClientCvar("g_scriptMainMenu", "main");
        player setClientCvar("cg_objectiveText", text);
        player spawnIntermission();
    }
    
    if ( (winningteam == "allies") || (winningteam == "axis") )
    {
        logPrint("W;" + winningteam + winners + "\n");
        logPrint("L;" + losingteam + losers + "\n");
    }
    
    wait 10;
    exitLevel(false);
}

checkTimeLimit()
{
    if(level.timelimit <= 0)
        return;
    
    timepassed = (getTime() - level.starttime) / 1000;
    timepassed = timepassed / 60.0;
    
    if(timepassed < level.timelimit)
        return;
    
    if(level.mapended)
        return;
    level.mapended = true;

    iprintln(&"MPSCRIPT_TIME_LIMIT_REACHED");
    endMap();
}

checkScoreLimit()
{
    if(level.scorelimit <= 0)
        return;
    
    if(getTeamScore("allies") < level.scorelimit && getTeamScore("axis") < level.scorelimit)
        return;

    if(level.mapended)
        return;
    level.mapended = true;

    iprintln(&"MPSCRIPT_SCORE_LIMIT_REACHED");
    endMap();
}

updateScriptCvars()
{
    for(;;)
    {
        timelimit = getcvarfloat("scr_tdm_timelimit");
        if(level.timelimit != timelimit)
        {
            if(timelimit > 1440)
            {
                timelimit = 1440;
                setcvar("scr_tdm_timelimit", "1440");
            }
            
            level.timelimit = timelimit;
            level.starttime = getTime();
            
            if(level.timelimit > 0)
            {
                if(!isdefined(level.clock))
                {
                    level.clock = newHudElem();
                    level.clock.x = 320;
                    level.clock.y = 440;
                    level.clock.alignX = "center";
                    level.clock.alignY = "middle";
                    level.clock.font = "bigfixed";
                }
                level.clock setTimer(level.timelimit * 60);
            }
            else
            {
                if(isdefined(level.clock))
                    level.clock destroy();
            }
            
            checkTimeLimit();
        }

        scorelimit = getcvarint("scr_tdm_scorelimit");
        if(level.scorelimit != scorelimit)
        {
            level.scorelimit = scorelimit;
            checkScoreLimit();
        }

        drawfriend = getcvarfloat("scr_drawfriend");
        if(level.drawfriend != drawfriend)
        {
            level.drawfriend = drawfriend;
            
            if(level.drawfriend)
            {
                // for all living players, show the appropriate headicon
                players = getentarray("player", "classname");
                for(i = 0; i < players.size; i++)
                {
                    player = players[i];
                    
                    if(isdefined(player.pers["team"]) && player.pers["team"] != "spectator" && player.sessionstate == "playing")
                    {
                        if(player.pers["team"] == "allies")
                        {
                            player.headicon = game["headicon_allies"];
                            player.headiconteam = "allies";
                        }
                        else
                        {
                            player.headicon = game["headicon_axis"];
                            player.headiconteam = "axis";
                        }
                    }
                }
            }
            else
            {
                players = getentarray("player", "classname");
                for(i = 0; i < players.size; i++)
                {
                    player = players[i];
                    
                    if(isdefined(player.pers["team"]) && player.pers["team"] != "spectator" && player.sessionstate == "playing")
                        player.headicon = "";
                }
            }
        }

        allowvote = getcvarint("g_allowvote");
        if(level.allowvote != allowvote)
        {
            level.allowvote = allowvote;
            setcvar("scr_allow_vote", allowvote);
        }

        wait 1;
    }
}

printJoinedTeam(team)
{
    if(team == "allies")
        iprintln(&"MPSCRIPT_JOINED_ALLIES", self);
    else if(team == "axis")
        iprintln(&"MPSCRIPT_JOINED_AXIS", self);
}

dropHealth()
{
    if(isdefined(level.healthqueue[level.healthqueuecurrent]))
        level.healthqueue[level.healthqueuecurrent] delete();
    
    level.healthqueue[level.healthqueuecurrent] = spawn("item_health", self.origin + (0, 0, 1));
    level.healthqueue[level.healthqueuecurrent].angles = (0, randomint(360), 0);

    level.healthqueuecurrent++;
    
    if(level.healthqueuecurrent >= 16)
        level.healthqueuecurrent = 0;
}

addBotClients()
{
    wait 5;
    
    for(;;)
    {
        if(getCvarInt("scr_numbots") > 0)
            break;
        wait 1;
    }
    
    iNumBots = getCvarInt("scr_numbots");
    for(i = 0; i < iNumBots; i++)
    {
        ent[i] = addtestclient();
        wait 0.5;

        if(isPlayer(ent[i]))
        {
            if(i & 1)
            {
                ent[i] notify("menuresponse", game["menu_team"], "axis");
                wait 0.5;
                ent[i] notify("menuresponse", game["menu_weapon_axis"], "kar98k_mp");
            }
            else
            {
                ent[i] notify("menuresponse", game["menu_team"], "allies");
                wait 0.5;
                ent[i] notify("menuresponse", game["menu_weapon_allies"], "springfield_mp");
            }
        }
    }
}
/*
botcheck( ply ) {
    if ( !level.botmap )
        return false;

    if ( isDefined( ply ) ) {
        if ( !ply isBot() )
            return false;

        if ( !isAlive( ply ) || ply.sessionstate != "playing" )
            return false;
    }

    return true;
}

bot_addGoal( type, location_or_entity, priority ) {
    if ( !botcheck( self ) ) 
        return;

    if ( !isDefined( type ) || !isDefined( location_or_entity ) )
        return;

    struct_goal = bot_spawnGoalStruct();

    if ( typeof( location_or_entity ) == "vector" )
        struct_goal.location = location_or_entity;
    else
        struct_goal.entity = location_or_entity;

    if ( isDefined( priority ) )
        struct_goal.priority = priority;

    self.goals[ self.goals.size ] = struct_goal;
}

bot_spawnGoalStruct() {
    goal = spawnstruct();

    goal.location = ( 0, 0, 0 );
    goal.entity = undefined;
    goal.type = level.kBOT_GT_GENERIC;
    goal.priority = level.kBOT_GP_NORM;

    return goal;
}

bot_getNextGoal() {
    if ( !botcheck( self ) )
        return;

    if ( !isDefined( self.goals ) || self.goals.size == 0 )
        bot_setDefaultGoals();

    // only sort if we've added some goals since last time
    if ( self.goals_needsort )
        bot_sortGoals();

    nextgoal = undefined;
    lasttype = level.kBOT_GT_GENERIC;
    lastpriority = level.kBOT_GP_NONE;
    for ( i = 0; i < self.goals.size; i++ ) {
        goal = self.goals[ i ];

        // find the highest ranking goal
        // players are alway most important
        // player goals with a high priority setting are sought first
        if ( goal.type >= lasttype && goal.priority > lastpriority ) {
            nextgoal = goal;
            lasttype = goal.type;
            lastpriority = goal.priority;
        }
    }

    // couldn't find a goal
    if ( !isDefined( nextgoal ) ) {}
}

//
// bot_sortGoals()
// sorts goals by priority, highest first
//
bot_sortGoals() {
    if ( !botcheck( self ) )
        return;

    priority_highest = [];      priority_high = [];
    priority_norm = [];         priority_low = [];
    priority_lowest = [];

    // sort goals
    for ( i = 0; i < self.goals.size; i++ ) {
        goal = self.goals[ i ];

        // delete this goal
        if ( goal.priority == level.kBOT_GP_NONE )
            continue;

        switch ( goal.priority ) {
            case level.kBOT_GP_LOWEST:      priority_lowest [ priority_lowest.size  ] = goal; break;
            case level.kBOT_GP_LOW:         priority_low    [ priority_low.size     ] = goal; break;
            case level.kBOT_GP_NORM:        priority_norm   [ priority_norm.size    ] = goal; break;
            case level.kBOT_GP_HIGH:        priority_high   [ priority_high.size    ] = goal; break;
            case level.kBOT_GP_HIGHEST:     priority_highest[ priority_highest.size ] = goal; break;
            default: 
                continue;
                break;
        }
    }

    goals = [];

    for ( i = 0; i < priority_highest.size; i++ )   goals[ goals.size ] = priority_highest[ i ];
    for ( i = 0; i < priority_high.size; i++ )      goals[ goals.size ] = priority_high[ i ];
    for ( i = 0; i < priority_norm.size; i++ )      goals[ goals.size ] = priority_norm[ i ];
    for ( i = 0; i < priority_low.size; i++ )       goals[ goals.size ] = priority_low[ i ];
    for ( i = 0; i < priority_lowest.size; i++ )    goals[ goals.size ] = priority_lowest[ i ];

    self.goals = goals;
}

bots_init() {
    level.botmap = false;
    level.botsconnect = false;

    printconsole( frame() + "\n" );

// globals
    //
    // goal priorities
    // stack-based system
    // highest priorities get factored first
    // filter through until all priorties have been met, cycle
    //
    level.kBOT_GP_NONE = 0;         // delete goal
    level.kBOT_GP_LOWEST = 1;       
    level.kBOT_GP_LOW = 2;          // default spots like spawnpoints
    level.kBOT_GP_NORM = 4;         // common spots on maps
    level.kBOT_GP_HIGH = 8;
    level.kBOT_GP_HIGHEST = 16;     // player priority spots
    //

    //
    // goal types
    //
    level.kBOT_GT_GENERIC = 0;      // generic goal
    level.kBOT_GT_SPAWNPOINT = 1;   
    level.kBOT_GT_COMMON_SPOT = 2;
    level.kBOT_GT_ENTITY = 4;
    level.kBOT_GT_PLAYER = 8;
    //

    //
    // bot state
    // tells the game what the bot is doing 
    //
    level.kBOT_BS_INIT = 0;         // init state
    level.kBOT_BS_IDLE = 1;         // signals we need a goal
    level.kBOT_BS_SPAWNING = 2;     // set when bot is spawning
    level.kBOT_BS_CHASEGOAL = 4;    // chasing a goal
    level.kBOT_BS_CHASEPLAYER = 8;  // chasing a player
    level.kBOT_BS_DEAD = 16;        // no longer living, final state
    //


    level.kBOT_NONE = 0;
    level.kBOT_IDLE = 1;
    level.kBOT_ROAM = 2;
    level.kBOT_CHASE = 4;
    level.kBOT_DEAD = 8;

    level.kBOT_WANDER = 16;
    level.kBOT_SEARCH = 32;
    level.kBOT_FOLLOWPLAYER = 64;


    level.falldamagemax = 512;

    wpfile = "waypoints/" + getCvar( "mapname" ) + ".wp";
    if ( wp_init( wpfile ) )
        level.botmap = true;
}

bots_main() {
    if ( !botcheck() )
        return;

    level.maxzdepth = -4;

    players = getEntArray( "player", "classname" );
    while ( players.size == 0 ) {
        players = getEntArray( "player", "classname" );
        wait 0.05;
    }

    wait 2;

    bot = bots_addBot();
    if ( !isDefined( bot ) ) {
        printconsole( "unable to add bot for some reason\n" );
        return;
    }

    bot bots_setupBot();
    bot bots_spawnZombie();
}

bots_addBot() {
    bot = addtestclient();

    wait 0.5;

    if ( isPlayer( bot ) ) 
        return bot;
    else
        return undefined;
}

bots_setupBot() {
    if ( !botcheck( self ) )
        return;

    self.bot = spawnstruct();

    // think logic
    self.bot.think = ::bots_zomThink;
    self.bot.nextthink = ::bots_zomThink;

    // usually a player
    self.bot.target = undefined;
    self.bot.goal = level.kBOT_NONE;
    self.bot.status = level.kBOT_IDLE;
    self.bot.idlewaittime = 0;
    self.bot.moving = false;
    self.bot.falling = false;
}

bots_spawnZombie() {
    if ( !botcheck( self ) )
        return;

    self.pers[ "team" ] = "allies";
    self.pers[ "weapon" ] = "enfield_mp";

    self spawnPlayer();

    self.bot.node = spawn( "script_origin", self getOrigin() );
    self linkto( self.bot.node );

    self thread bots_thinkLogic();
}

bots_zomThink() {
    if ( !botcheck( self ) )
        return;

    // are there any near-by players?
    if ( self.bot.status == level.kBOT_CHASE ) {
        // follow a player
    }

    if ( !self bots_isOnGround() && !self.bot.falling ) {
        // drop to ground
        self notify( "stop_bot_moveto" );

        iPrintLn( "falling" );

        self.bot.falling = true;
        trace = bullettrace( self.bot.node.origin, self.bot.node.origin + ( 0, 0, -10000 ), true, self );
        if ( distance( self.node.origin, trace[ "position" ] ) > level.falldamagemax ) {
            iPrintLn( "would have died here" );
            return;
        }

        self thread bots_moveTo( trace[ "position" ] );

        return;
    }
       
    if ( self bots_isOnGround() && self.bot.falling ) {
        self.bot.falling = false;

        iPrintLn( "stopped falling" );
    }

    // we're roaming around
    if ( self.bot.status == level.kBOT_ROAM ) {
        // we're already moving, chances are 
        // we've got a waypoint and are en-route
        if ( self.bot.moving ) 
            return;

        // let's try and nab the 10 closest waypoints
        waypoints = wp_getXClosest( self.bot.node.origin, 10 );
        if ( !isDefined( waypoints ) || waypoints.size == 0 ) {
            iPrintLn( "couldn't find any waypoints" );
            // bummer, no waypoints, let's just sit here
            return;
        }

        // let's pick a random waypoint to move to
        id = waypoints[ randomInt( waypoints.size ) ];
        wp = wp_getByID( id );
        if ( !isDefined( wp ) ) {
            iPrintLn( "waypoint is undefined" );
            return;
        }

        if ( wp[ "position" ][ 2 ] < level.maxzdepth ) {
            iPrintLn( "wp < level.maxzdepth" );
            return;
        }

        self thread bots_moveTo( wp[ "position" ] );
    }

    // we're just sitting idle, maybe let's do something?
    if ( self.bot.status == level.kBOT_IDLE ) {
        if ( self.bot.idlewaittime < 0 )
            self.botidlewaittime = 0;

        // if we're supposed to sit around, then let's do that
        if ( self.bot.idlewaittime > 0 ) {
            self.bot.idlewaittime -= frame();
            return;
        }

        // if we don't have a player,
        // let's just roam around until we find one
        if ( self.bot.goal == level.kBOT_NONE || 
             self.bot.goal == level.kBOT_WANDER )
            self.bot.status = level.kBOT_ROAM;
    }
}

bots_isOnGround() {
    mins = ( -15, -15, 0 );
    maxs = ( 15, 15, 70 );
    trace = trace( self.bot.node.origin, mins, maxs, self.bot.node.origin + ( 0, 0, -10000 ), self getEntityNumber(), 1 );
    if ( trace[ "fraction" ] == 1 )
        return false;

    return true;
}

bots_canSeeLoc( loc ) {
    if ( !botcheck( self ) )
        return;

    if ( !isDefined( loc ) )
        return;

    mins = ( -15, -15, 0 );
    maxs = ( 15, 15, 70 );
    trace = trace( self.bot.node.origin + ( 0, 0, 60 ), mins, maxs, loc, self getEntityNumber(), 1 );
    if ( trace[ "fraction" ] == 1 && trace[ "contents" ] < 1 )
        return true;

    //trace = bullettrace( self getOrigin() + ( 0, 0, 60 ), loc, true, self );
    //if ( trace[ "fraction" ] == 1 )
    //    return true;

    //trace = trace( self getOrigin() + ( 0, 0, 60 ), mins, maxs, wp[ "position" ] + ( 0, 0, 60 ), self getEntityNumber(), 1 );
    //if ( trace[ "fraction" ] == 1 )
    //    return true;

    return false;
}

bots_tracedOutLoc( loc ) {
    if ( !botcheck( self ) )
        return;

    if ( !isDefined( loc ) )
        return;

    mins = ( -15, -15, 0 );
    maxs = ( 15, 15, 70 );
    trace = trace( loc + ( 0, 0, 60 ), mins, maxs, loc + ( 0, 0, -10000 ), self getEntityNumber(), 1 );
    if ( trace[ "fraction" ] == 1 )
        return undefined;

    return trace[ "position" ];
}

bots_locToWP( loc ) {
    wp = [];
    wp[ "position" ] = loc;

    return wp;
}

bots_moveTo( pos ) {
    if ( !botcheck( self ) )
        return;

    if ( !isDefined( pos ) )
        return;

    if ( !self bots_canSeeLoc( pos ) )
        return;

    loc = self bots_tracedOutLoc( pos );
    if ( !isDefined( loc ) ) {
        // problem tracing out location
        return;
    }

    iPrintLn( "moving to " + loc );

    self.bot.moving = true;

    self endon( "bot_stop_moveto" );

    angles = vectorToAngles( loc - self.bot.node.origin );
    step = self.bot.node.origin + maps\mp\_utility::vectorscale( anglesToForward( angles ), 190 );
    t = distance( self.bot.node.origin, step ) / 190;
    self.bot.node moveTo( step, t );
    self.bot.node rotateTo( angles, 0.2 );
    self setPlayerAngles( angles );

    wait t;

    self.bot.moving = false;
}

bots_thinkLogic() {
    if ( !botcheck( self ) )
        return;

    self [[ self.bot.think ]]();

    while ( self.bot.status != level.kBOT_DEAD ) {
        if ( isDefined( self.bot.nextthink ) )
            self [[ self.bot.nextthink ]]();

        wait frame();
    }
}
*/
shit() {

}