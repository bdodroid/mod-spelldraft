-- Random Enchantment (RE) system Wave 2: display (form-changer) and proc enchants.
-- IDs 900001+ are module-authored (Ascension source IDs stay below 1.8M; no overlap).
--
-- handler 'display': handler_data = "<formAuraId>[,<formAuraId>...]:<displayId>"
--     While shapeshifted into one of the listed form auras, the player's model
--     is overridden with the given creature display ID.
-- handler 'proc': handler_data = recipe key implemented in spelldraft_re.lua.

DELETE FROM `custom_random_enchantments` WHERE `id` BETWEEN 900001 AND 900018;
INSERT INTO `custom_random_enchantments`
    (`id`, `name`, `tooltip`, `quality`, `weight`, `min_level`, `slot_mask`, `handler`, `handler_data`) VALUES
    (900001, 'Spirit of Arcturis', 'While in Bear Form or Dire Bear Form, you take the shape of the spirit bear Arcturis.', 5, 3, 20, 65535, 'display', '5487,9634:31094'),
    (900002, 'Plaguebear', 'While in Bear Form or Dire Bear Form, you take the shape of a plague-ridden grizzly.', 4, 8, 15, 65535, 'display', '5487,9634:1083'),
    (900003, 'Spectre of Gondria', 'While in Cat Form, you take the shape of the spectral tiger Gondria.', 5, 3, 20, 65535, 'display', '768:28871'),
    (900004, 'Ghost Saber', 'While in Cat Form, you take the shape of the spectral snow leopard Har\'koa.', 4, 8, 15, 65535, 'display', '768:99851'),
    (900005, 'Spirit of Skoll', 'While in Ghost Wolf form, you take the shape of the storm wolf Skoll.', 4, 8, 15, 65535, 'display', '2645:29673'),
    (900011, 'Sparkflame', 'Your Fireball casts have a 15% chance to hurl a free Fire Blast at your target.', 4, 8, 20, 65535, 'proc', 'sparkflame'),
    (900012, 'Thunderstruck', 'Your Lightning Bolt casts have a 15% chance to unleash a free Chain Lightning.', 4, 8, 20, 65535, 'proc', 'thunderstruck'),
    (900013, 'Echo of the Mind', 'Casting Shadow Word: Pain has a 25% chance to reset the cooldown of Mind Blast.', 4, 8, 20, 65535, 'proc', 'echomind'),
    (900014, 'Battlemage''s Reflex', 'Your melee strikes have a 10% chance to fire an Ice Lance at your target. (6 sec cooldown)', 5, 3, 30, 65535, 'proc', 'battlemage'),
    (900015, 'Huntmaster''s Vigor', 'Killing an enemy restores 5% of your health and mana. (5 sec cooldown)', 4, 8, 15, 65535, 'proc', 'killheal'),
    (900016, 'Last Bastion', 'Falling below 30% health in combat shields you with Power Word: Shield. (60 sec cooldown)', 5, 3, 30, 65535, 'proc', 'lastbastion'),
    (900017, 'Verdant Echo', 'Your heals have a 15% chance to also place Renew on the target. (4 sec cooldown)', 4, 8, 20, 65535, 'proc', 'verdantecho'),
    (900018, 'Stormsurge', 'Your damaging attacks and spells have a 5% chance to call Chain Lightning upon your target. (8 sec cooldown)', 5, 3, 30, 65535, 'proc', 'stormsurge');
