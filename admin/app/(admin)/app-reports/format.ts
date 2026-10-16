export const CATEGORY_LABELS: Record<string, string> = {
  schedule: "Jadwal salah",
  notification: "Notifikasi atau suara tidak berbunyi",
  map: "Peta atau posisi kereta",
  forum: "Forum atau penyalahgunaan",
  account: "Akun atau login",
  other: "Lainnya",
};

export function formatDate(value: string) {
  return new Date(value).toLocaleString("id-ID", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}
