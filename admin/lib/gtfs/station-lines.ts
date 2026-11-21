/**
 * Urutan stasiun pada satu lini untuk `station_lines.stop_order`.
 *
 * Perjalanan terpanjang tiap rute ([canonical]) menentukan urutan dasar. Stasiun
 * yang hanya dilewati pola lain ([otherTrips], mis. cabang atau pola via kota
 * lain) dulu tidak mendapat baris sama sekali, dan aplikasi menganggap stasiun
 * tanpa lini sebagai Jabodetabek. Sekarang tiap stasiun mendapat nomor dari
 * tetangga sebelumnya di perjalanan yang sama.
 *
 * Bila ada stasiun tambahan, nomor dasar dijarangkan 100x supaya yang baru
 * mendapat nomor unik di antara tetangganya (paling banyak 99 per celah).
 * Tanpa stasiun tambahan hasilnya sama dengan sebelumnya: 1..N.
 */
export function orderStationsOnLine(
  canonical: string[],
  otherTrips: string[][],
): Map<string, number> {
  const orders = new Map<string, number>();
  canonical.forEach((stationId, index) => orders.set(stationId, index + 1));

  const hasExtras = otherTrips.some((trip) =>
    trip.some((stationId) => !orders.has(stationId)),
  );
  if (!hasExtras) return orders;

  for (const [stationId, order] of orders) orders.set(stationId, order * 100);
  for (const trip of otherTrips) {
    let last = 0;
    let bump = 0;
    for (const stationId of trip) {
      const known = orders.get(stationId);
      if (known !== undefined) {
        last = known;
        bump = 0;
        continue;
      }
      bump += 1;
      orders.set(stationId, last + Math.min(bump, 99));
    }
  }
  return orders;
}
