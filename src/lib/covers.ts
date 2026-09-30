import heroCover from '@/assets/covers/hero.jpg';
import survivalCover from '@/assets/covers/survival.jpg';
import techCover from '@/assets/covers/tech.jpg';
import modpackCover from '@/assets/covers/modpack.jpg';
import pvpCover from '@/assets/covers/pvp.jpg';
import type { Instance } from '@shared/types';

export const HERO_COVER = heroCover;

/**
 * Подбирает обложку сборке: сначала по имени (тех/моды/pvp/выживание),
 * иначе по кругу — чтобы у каждой карточки был свой визуал.
 */
export function coverFor(instance: Instance, index = 0): string {
  const key = `${instance.name} ${instance.icon}`.toLowerCase();
  if (/(тех|tech|автомат|factory|create|mekanism|машин)/.test(key)) return techCover;
  if (/(модпак|modpack|магия|magic|forge|шейдер)/.test(key)) return modpackCover;
  if (/(pvp|пвп|арена|arena|bedwars|хайпер|1\.8)/.test(key)) return pvpCover;
  if (/(выживан|survival|мир|world|основн|fabric|ванил)/.test(key)) return survivalCover;
  return [survivalCover, techCover, modpackCover, pvpCover][index % 4];
}
