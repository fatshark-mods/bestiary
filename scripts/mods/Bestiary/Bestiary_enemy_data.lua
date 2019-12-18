local breed_textures = UISettings.breed_textures
local skaven_lore_strings = dofile("scripts/mods/Bestiary/skaven_enemies_strings")

local stats_data = {
    skaven_warpfire_thrower = {
        {
            stat = "warpfire_kill_before_shooting",
            text = "Killed Before Shooting"
        },
        {
            stat = "warpfire_kill_on_power_cell",
            text = "Power Cells Destroyed"
        },
        {
            stat = "warpfire_enemies_incinerated",
            text = "Enemies Incinerated"
        }
    },
    skaven_poison_wind_globadier = {
        {
            stat = "globadier_kill_before_throwing",
            text = "Killed Before Throwing"
        },
        {
            stat = "globadier_kill_during_suicide",
            text = "Killed During Suicide"
        },
        {
            stat = "globadier_enemies_suffocated",
            text = "Enemies Suffocated"
        }
    },
    skaven_gutter_runner = {
        {
            stat = "gutter_runner_killed_on_pounce",
            text = "Killed Mid-Pounce"
        },
        {
            stat = "gutter_runner_push_on_pounce",
            text = "Pushed Mid-Pounce"
        },
        {
            stat = "gutter_runner_push_on_target_pounced",
            text = "Kills Interrupted"
        }
    },
    skaven_ratling_gunner = {
        {
            stat = "ratling_gunner_killed_by_melee",
            text = "Killed by Melee"
        },
        {
            stat = "ratling_gunner_killed_while_shooting",
            text = "Killed While Shooting"
        },
        {
            stat = "ratling_gunner_blocked_shot",
            text = "Shots Blocked"
        }
    },
    skaven_pack_master = {
        {
            stat = "pack_master_dodged_attack",
            text = "Grabs Dodged"
        },
        {
            stat = "pack_master_kill_abducting_ally",
            text = "Abductions Foiled"
        },
        {
            stat = "pack_master_rescue_hoisted_ally",
            text = "Hoisted Allies Rescued"
        }
    },
    chaos_corruptor_sorcerer = {
        {
            stat = "corruptor_killed_at_teleport_time",
            text = "Killed After Teleporting"
        },
        {
            stat = "corruptor_dodged_attack",
            text = "Projectiles Dodged"
        },
        {
            stat = "corruptor_killed_while_grabbing",
            text = "Leeched Allies Released"
        }
    },
    chaos_vortex_sorcerer = {
        {
            stat = "vortex_sorcerer_killed_while_summoning",
            text = "Killed While Conjuring"
        },
        {
            stat = "vortex_sorcerer_killed_while_ally_in_vortex",
            text = "Allies Grounded"
        },
        {
            stat = "vortex_sorcerer_killed_by_melee",
            text = "Killed by Melee"
        }
    },

    skaven_rat_ogre = {
        {
            stat = "rat_ogre_killed_mid_leap",
            text = "Killed Mid-Leap"
        },
        {
            stat = "rat_ogre_killed_without_dealing_damage",
            text = "Perfect Kill"
        }
    },
    skaven_stormfiend = {
        {
            stat = "stormfiend_killed_without_burn_damage",
            text = "Killed Without Burn Damage"
        },
        {
            stat = "stormfiend_killed_on_controller",
            text = "Controllers Gutted"
        }
    },
    chaos_troll = {
        {
            stat = "chaos_troll_killed_without_regen",
            text = "Killed Without Regenerating"
        },
        {
            stat = "chaos_troll_killed_without_bile_damage",
            text = "Killed Without Bile Damage"
        }
    },
    chaos_spawn = {
        {
            stat = "chaos_spawn_killed_while_grabbing",
            text = "Killed While Grabbing Ally"
        },
        {
            stat = "chaos_spawn_killed_without_having_grabbed",
            text = "Killed Without Being Grabbed"
        }
    }
}

local armor_categories = {
    "Infantry",
    "Armored",
    "Monster",
    "", --"Player",
    "Berserker",
    "Fully Armored"
}

local skaven_icon_slots = {
    {
        breed_textures.skaven_slave,
        "skaven_slave",
    },
    {
        breed_textures.skaven_clan_rat,
        {
            "skaven_clan_rat",
            "skaven_clan_rat_with_shield"
        }
    },
    {
        breed_textures.skaven_plague_monk,
        "skaven_plague_monk"
    },

    {
        breed_textures.skaven_storm_vermin,
        {
            "skaven_storm_vermin",
            "skaven_storm_vermin_with_shield",
        }
    },
    {
        breed_textures.skaven_warpfire_thrower,
        "skaven_warpfire_thrower"
    },
    {
        breed_textures.skaven_poison_wind_globadier,
        "skaven_poison_wind_globadier"
    },
    {
        breed_textures.skaven_gutter_runner,
        "skaven_gutter_runner"
    },
    {
        breed_textures.skaven_ratling_gunner,
        "skaven_ratling_gunner"
    },
    {
        breed_textures.skaven_pack_master,
        "skaven_pack_master"
    },
    {
        breed_textures.skaven_loot_rat,
        "skaven_loot_rat"
    },
    {
        breed_textures.skaven_rat_ogre,
        "skaven_rat_ogre"
    },
    {
        breed_textures.skaven_stormfiend,
        "skaven_stormfiend"
    },
    {
        breed_textures.skaven_storm_vermin_warlord,
        "skaven_storm_vermin_warlord"
    },
    {
        breed_textures.skaven_stormfiend_boss,
        "skaven_stormfiend_boss"
    },
    {
        breed_textures.skaven_grey_seer,
        "skaven_grey_seer"
    }
}

local chaos_icon_slots = {
    {
        breed_textures.chaos_fanatic,
        "chaos_fanatic"
    },
    {
        breed_textures.chaos_marauder,
        {
            "chaos_marauder",
            "chaos_marauder_with_shield"
        }
    },
    {
        breed_textures.chaos_berzerker,
        "chaos_berzerker"
    },
    {
        breed_textures.chaos_raider,
        "chaos_raider"
    },
    {
        breed_textures.chaos_warrior,
        "chaos_warrior",
    },
    {
        breed_textures.chaos_corruptor_sorcerer,
        "chaos_corruptor_sorcerer"
    },
    {
        breed_textures.chaos_vortex_sorcerer,
        "chaos_vortex_sorcerer"
    },
    {
        breed_textures.chaos_troll,
        "chaos_troll"
    },
    {
        breed_textures.chaos_spawn,
        "chaos_spawn"
    },
    {
        breed_textures.chaos_exalted_sorcerer,
        "chaos_exalted_sorcerer"
    },
    {
        breed_textures.chaos_exalted_champion_warcamp,
        "chaos_exalted_champion_warcamp"
    },
    {
        breed_textures.chaos_exalted_champion_norsca,
        {
            "chaos_exalted_champion_norsca",
            "chaos_spawn_exalted_champion_norsca"
        }

    },
    {
        breed_textures.beastmen_ungor,
        {
            "beastmen_ungor",
            "beastmen_ungor_archer"
        }
    },
    {
        breed_textures.beastmen_gor,
        "beastmen_gor"
    },
    {
        breed_textures.beastmen_bestigor,
        "beastmen_bestigor"
    },
    {
        breed_textures.beastmen_standard_bearer,
        "beastmen_standard_bearer"
    },
    {
        breed_textures.beastmen_minotaur,
        "beastmen_minotaur"
    }
}

local beastmen_icon_slots = {

}

local enemy_info = {
    skaven_slave = {},
    skaven_clan_rat = {},
    skaven_clan_rat_with_shield = {},
    skaven_plague_monk = {},
    skaven_loot_rat = {},
    skaven_storm_vermin = {},
    skaven_storm_vermin_with_shield = {},
    skaven_warpfire_thrower = {},
    skaven_poison_wind_globadier = {},
    skaven_gutter_runner = {},
    skaven_ratling_gunner = {},
    skaven_pack_master = {},
    skaven_rat_ogre = {},
    skaven_stormfiend = {},
    skaven_storm_vermin_warlord = {},
    skaven_stormfiend_boss = {},
    skaven_grey_seer = {},
    
    chaos_fanatic = {},
    chaos_marauder = {},
    chaos_marauder_with_shield = {},
    chaos_berzerker = {},
    chaos_raider = {},
    chaos_warrior = {},
    chaos_corruptor_sorcerer = {},
    chaos_vortex_sorcerer = {},
    chaos_troll = {},
    chaos_spawn = {},
    chaos_exalted_sorcerer = {},
    chaos_exalted_champion_warcamp = {},
    chaos_exalted_champion_norsca = {},
    chaos_spawn_exalted_champion_norsca = {},

    beastmen_bestigor = {},
    beastmen_gor = {},
    beastmen_minotaur = {},
    beastmen_standard_bearer = {},
    beastmen_ungor = {},
    beastmen_ungor_archer = {}
}

for breed_name, breed in pairs(enemy_info) do

    local template_name = Breeds[breed_name].default_inventory_template
    local template_function = AIInventoryTemplates[template_name]

    local inventory_config
    if template_function then
        local config_name = template_function()
        inventory_config = InventoryConfigurations[config_name]
    end

    breed.name = Localize(breed_name)
    breed.inventory_config = inventory_config
    breed.race = Breeds[breed_name].race
    breed.armor_category = armor_categories[Breeds[breed_name].armor_category]
    breed.boss = Breeds[breed_name].boss
    breed.elite = Breeds[breed_name].elite
    breed.special = Breeds[breed_name].special
    breed.health = Breeds[breed_name].max_health
    breed.hit_mass = Breeds[breed_name].hit_mass_counts or Breeds[breed_name].hit_mass_count or 1
    breed.block_mass = Breeds[breed_name].hit_mass_counts_block or Breeds[breed_name].hit_mass_count_block
    breed.stagger_resist = Breeds[breed_name].diff_stagger_resist or Breeds[breed_name].stagger_resistance or 2
    breed.linesman_mod = LINESMAN_HIT_MASS_COUNT[breed_name]
    breed.tank_mod = TANK_HIT_MASS_COUNT[breed_name]
    breed.heavy_linesman_mod = HEAVY_LINESMAN_HIT_MASS_COUNT[breed_name]
    breed.man_sized = not Breeds[breed_name].boss and not Breeds[breed_name].primary_armor_category  -- From damage_utils.lua:274

    breed.lore_strings = skaven_lore_strings[breed_name]
    breed.stats_data = stats_data[breed_name]
end

--[[
    Manual Overrides
]]

-- Combine the statistics for the following breeds
enemy_info.skaven_storm_vermin.combine_with = "skaven_storm_vermin_commander"
enemy_info.skaven_storm_vermin_with_shield.combine_with = "skaven_storm_vermin_commander_with_shield"
enemy_info.chaos_exalted_champion_norsca.combine_with = "chaos_spawn_exalted_champion_norsca"
enemy_info.chaos_spawn_exalted_champion_norsca.combine_with = "chaos_exalted_champion_norsca"

-- Prune ambiguity
enemy_info.skaven_clan_rat_with_shield.name = enemy_info.skaven_clan_rat.name.." (Shielded)"
enemy_info.skaven_clan_rat_with_shield.armor_category = "Infantry"
enemy_info.skaven_storm_vermin_with_shield.name = enemy_info.skaven_storm_vermin.name.." (Shielded)"

-- Correct a few missing/incorrect names
enemy_info.chaos_fanatic.name = "Fanatic"
enemy_info.chaos_corruptor_sorcerer.name = "Lifeleech"
enemy_info.chaos_vortex_sorcerer.name = "Blightstormer"
enemy_info.beastmen_ungor.name = "Ungor"
enemy_info.beastmen_ungor_archer.name = "Ungor Archer"
enemy_info.beastmen_gor.name = "Gor"
enemy_info.beastmen_bestigor.name = "Bestigor"
enemy_info.beastmen_standard_bearer.name = "Standard Bearer"

-- Assign lordship for icon purposes
enemy_info.skaven_storm_vermin_warlord.lord = true
enemy_info.skaven_grey_seer.lord = true
enemy_info.chaos_exalted_sorcerer.lord = true
enemy_info.chaos_exalted_champion_warcamp.lord = true
enemy_info.chaos_exalted_champion_norsca.lord = true
enemy_info.chaos_spawn_exalted_champion_norsca.lord = true
enemy_info.skaven_stormfiend_boss.lord = true


-- Override Gatekeeper Naglfahr's inventory template to bypass unit spawning issues with his usual axes
enemy_info.chaos_exalted_champion_norsca.inventory_config = {
    anim_state_event = "to_spear",
    items = {
        {
            {
                drop_on_hit = true,
                unit_name = "units/weapons/enemy/wpn_chaos_set/wpn_chaos_2h_axe_03",
                attachment_node_linking = AttachmentNodeLinking.ai_2h
            }
        }
    }
}

-- Override Ungor Archer inventory template until config switching is implemented
enemy_info.beastmen_ungor_archer.inventory_config = table.clone(InventoryConfigurations.beastmen_ungor_spear)
enemy_info.beastmen_ungor_archer.inventory_config.anim_state_event = InventoryConfigurations.beastmen_ungor_bow.anim_state_event
enemy_info.beastmen_ungor_archer.inventory_config.items[1] = InventoryConfigurations.beastmen_ungor_bow.items[1]

return {
    skaven_icon_slots = skaven_icon_slots,
    chaos_icon_slots = chaos_icon_slots,
    beastmen_icon_slots = beastmen_icon_slots,
    enemy_info = enemy_info
}