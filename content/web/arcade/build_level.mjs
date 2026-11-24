import { createLevel, canExit } from './compile_input.ts';

try {
  const { title, intro, rows, moveLimit } = createLevel();
  if (!Array.isArray(rows) || rows.length < 4 || rows.length > 8 ||
      rows.some(row => typeof row !== 'string' || row.length < 4 || row.length > 8)) {
    throw new Error('rows must be a 4–8 by 4–8 grid of strings');
  }
  if (typeof title !== 'string' || title.length < 1 || title.length > 56 ||
      typeof intro !== 'string' || intro.length > 150 || !Number.isInteger(moveLimit)) {
    throw new Error('Use a short title and intro, and an integer moveLimit');
  }
  const packets = rows.join('').split('P').length - 1;
  if (packets > 8) throw new Error('Use up to 8 packets');
  const exits = Array.from({ length: packets + 1 }, (_, collected) => canExit(collected, packets));
  if (exits.some(value => typeof value !== 'boolean')) throw new Error('canExit must return true or false');
  console.log('CODIEN_ARCADE=' + JSON.stringify({ level: { title, intro, rows, moveLimit }, exits }));
} catch (error) {
  console.error(String(error?.message ?? error));
  process.exitCode = 1;
}
