import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/game_constants.dart';
import '../../data/models/item_model.dart';
import '../../data/models/game_state_model.dart';
import '../providers/game_providers.dart';

/// Inventory screen
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    final gold = ref.watch(goldProvider);

    if (inventory == null) {
      return const Center(
        child: Text('No inventory loaded'),
      );
    }

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: _buildHeader(context, inventory, gold),
        ),
        
        // Tab bar
        Container(
          color: AppColors.bgDark,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.dragonGold,
            labelColor: AppColors.dragonGold,
            unselectedLabelColor: AppColors.parchmentDark,
            tabs: const [
              Tab(text: 'All Items'),
              Tab(text: 'Equipment'),
              Tab(text: 'Consumables'),
            ],
          ),
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildItemGrid(inventory.items),
              _buildItemGrid(inventory.items
                  .where((i) => i.isEquippable)
                  .toList()),
              _buildItemGrid(inventory.items
                  .where((i) => i.isConsumable)
                  .toList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, InventoryModel inventory, int gold) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${inventory.items.length}/${inventory.maxSlots} slots',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.parchmentDark,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Weight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgMedium,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.parchmentDark.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, size: 16, color: AppColors.parchmentDark),
                const SizedBox(width: 6),
                Text(
                  '${inventory.totalWeight.toStringAsFixed(1)} lb',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Gold
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.charismaGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.charismaGold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, size: 16, color: AppColors.charismaGold),
                const SizedBox(width: 6),
                Text(
                  '$gold',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.charismaGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGrid(List<ItemModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.parchmentDark.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No items',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.parchmentDark,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _ItemCard(
          item: items[index],
          onTap: () => _showItemDetails(items[index]),
        ).animate()
          .fadeIn(delay: Duration(milliseconds: index * 50), duration: 300.ms)
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 300.ms);
      },
    );
  }

  void _showItemDetails(ItemModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ItemDetailSheet(item: item),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const _ItemCard({
    required this.item,
    required this.onTap,
  });

  Color get _rarityColor => Color(item.rarity.colorValue);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgMedium,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _rarityColor.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _rarityColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item icon
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _rarityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getItemIcon(),
                      color: _rarityColor,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  if (item.isStackable && item.quantity > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${item.quantity}',
                        style: TextStyle(
                          color: AppColors.parchment,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              
              const Spacer(),
              
              // Item name
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _rarityColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Item type
              Text(
                item.type.displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.parchmentDark,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getItemIcon() {
    switch (item.type) {
      case ItemType.weapon:
        return Icons.gavel;
      case ItemType.armor:
        return Icons.shield;
      case ItemType.shield:
        return Icons.security;
      case ItemType.potion:
        return Icons.science;
      case ItemType.scroll:
        return Icons.description;
      case ItemType.wand:
        return Icons.auto_fix_high;
      case ItemType.ring:
        return Icons.trip_origin;
      case ItemType.amulet:
        return Icons.diamond;
      case ItemType.tool:
        return Icons.build;
      case ItemType.consumable:
        return Icons.restaurant;
      case ItemType.treasure:
        return Icons.monetization_on;
      case ItemType.questItem:
        return Icons.star;
      case ItemType.misc:
        return Icons.inventory_2;
    }
  }
}

class _ItemDetailSheet extends StatelessWidget {
  final ItemModel item;

  const _ItemDetailSheet({required this.item});

  Color get _rarityColor => Color(item.rarity.colorValue);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rarityColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _rarityColor.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _rarityColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _rarityColor),
                  ),
                  child: Icon(
                    _getItemIcon(),
                    color: _rarityColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _rarityColor,
                        ),
                      ),
                      Text(
                        '${item.rarity.displayName} ${item.type.displayName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.parchmentDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              item.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.parchment,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  icon: Icons.fitness_center,
                  label: 'Weight',
                  value: '${item.weight} lb',
                ),
                _StatChip(
                  icon: Icons.monetization_on,
                  label: 'Value',
                  value: '${item.value} gp',
                ),
                if (item.isStackable)
                  _StatChip(
                    icon: Icons.layers,
                    label: 'Quantity',
                    value: '${item.quantity}',
                  ),
              ],
            ),
          ),
          
          // Weapon/Armor specific stats
          if (item is WeaponModel)
            _buildWeaponStats(context, item as WeaponModel),
          if (item is ArmorModel)
            _buildArmorStats(context, item as ArmorModel),
          if (item is PotionModel)
            _buildPotionStats(context, item as PotionModel),
          
          const SizedBox(height: 20),
          
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (item.isEquippable)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement equip
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Equip'),
                    ),
                  ),
                if (item.isConsumable) ...[
                  if (item.isEquippable) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement use
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.local_drink),
                      label: const Text('Use'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWeaponStats(BuildContext context, WeaponModel weapon) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgMedium,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  icon: Icons.gavel,
                  label: 'Damage',
                  value: weapon.damage,
                  color: AppColors.dragonBlood,
                ),
                _StatChip(
                  icon: Icons.whatshot,
                  label: 'Type',
                  value: weapon.damageType.displayName,
                  color: AppColors.dragonBlood,
                ),
              ],
            ),
            if (weapon.weaponProperties.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: weapon.weaponProperties.map((prop) {
                  return Chip(
                    label: Text(
                      prop.displayName,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: AppColors.bgDark,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArmorStats(BuildContext context, ArmorModel armor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgMedium,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatChip(
              icon: Icons.shield,
              label: 'AC',
              value: '${armor.baseArmorClass}',
              color: AppColors.arcaneBlue,
            ),
            _StatChip(
              icon: Icons.category,
              label: 'Type',
              value: armor.armorType.displayName,
              color: AppColors.arcaneBlue,
            ),
            if (armor.stealthDisadvantage)
              const _StatChip(
                icon: Icons.visibility_off,
                label: 'Stealth',
                value: 'Disadvantage',
                color: AppColors.warning,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPotionStats(BuildContext context, PotionModel potion) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgMedium,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatChip(
              icon: Icons.science,
              label: 'Effect',
              value: potion.effect.displayName,
              color: AppColors.forestGreen,
            ),
            if (potion.effectValue != null)
              _StatChip(
                icon: Icons.healing,
                label: 'Value',
                value: potion.effectValue!,
                color: AppColors.forestGreen,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getItemIcon() {
    switch (item.type) {
      case ItemType.weapon:
        return Icons.gavel;
      case ItemType.armor:
        return Icons.shield;
      case ItemType.shield:
        return Icons.security;
      case ItemType.potion:
        return Icons.science;
      case ItemType.scroll:
        return Icons.description;
      case ItemType.wand:
        return Icons.auto_fix_high;
      case ItemType.ring:
        return Icons.trip_origin;
      case ItemType.amulet:
        return Icons.diamond;
      case ItemType.tool:
        return Icons.build;
      case ItemType.consumable:
        return Icons.restaurant;
      case ItemType.treasure:
        return Icons.monetization_on;
      case ItemType.questItem:
        return Icons.star;
      case ItemType.misc:
        return Icons.inventory_2;
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? AppColors.parchmentDark;
    
    return Column(
      children: [
        Icon(icon, color: displayColor, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.parchmentDark,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: displayColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}


