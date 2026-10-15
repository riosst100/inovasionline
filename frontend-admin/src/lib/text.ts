/** "BANJAR HARJO" -> "Banjar Harjo" */
export const titleCase = (s: string) => s.toLowerCase().replace(/(^|[\s-])\S/g, (m) => m.toUpperCase());
