/// Thousand-separator VNĐ formatting for notification text. Deliberately
/// not `toLocaleString('vi-VN')` — that depends on Node being built with
/// full ICU data, which isn't guaranteed on every deploy target.
export function formatVndAmount(amount: number): string {
  return Math.round(amount)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}
