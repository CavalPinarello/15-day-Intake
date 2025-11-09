import fs from 'fs';
import path from 'path';

const INPUT_PATH = path.resolve(__dirname, '..', 'data', 'Sleep_360_Complete_Database.md');
const OUTPUT_PATH = path.resolve(__dirname, '..', 'data', 'sleep360_questions.json');

const markdown = fs.readFileSync(INPUT_PATH, 'utf8');
const lines = markdown.split(/\r?\n/);

const questions = [];
let currentPillar = '';
let currentTier = null;
let pendingQuestion = null;

function flushQuestion() {
  if (pendingQuestion) {
    questions.push(pendingQuestion);
    pendingQuestion = null;
  }
}

function parseTimeMinutes(value) {
  if (!value) return undefined;
  const match = value.match(/([\d.]+)\s*(?:min|minutes?)/i);
  if (match) return parseFloat(match[1]);
  return undefined;
}

for (const rawLine of lines) {
  const line = rawLine.trim();

  if (line.startsWith('### ')) {
    flushQuestion();
    currentPillar = line.replace(/^###\s+/, '').trim();
    continue;
  }

  const tierMatch = line.match(/^####\s+(CORE|EXPANSION|GATEWAY)\s+Questions/i);
  if (tierMatch) {
    flushQuestion();
    currentTier = tierMatch[1].toUpperCase();
    continue;
  }

  const questionMatch = line.match(/^\*\*(.+?)\*\*:\s*(.+)$/);
  if (questionMatch && currentTier && currentPillar) {
    flushQuestion();
    const [_, idRaw, text] = questionMatch;
    pendingQuestion = {
      id: idRaw.trim(),
      text: text.trim(),
      pillar: currentPillar,
      tier: currentTier,
    };
    continue;
  }

  if (!pendingQuestion) continue;

  const metaMatch = line.match(/^- \*(.+?)\*:\s*(.+)$/);
  if (metaMatch) {
    const [, keyRaw, valueRaw] = metaMatch;
    const key = keyRaw.toLowerCase();
    const value = valueRaw.trim();
    if (key.includes('scale/type')) {
      pendingQuestion.scaleType = value;
    } else if (key.includes('trigger')) {
      pendingQuestion.trigger = value;
    } else if (key.includes('time')) {
      pendingQuestion.timeMinutes = parseTimeMinutes(value);
    } else {
      pendingQuestion.notes = pendingQuestion.notes || [];
      pendingQuestion.notes.push(`${keyRaw}: ${value}`);
    }
    continue;
  }

  if (line) {
    pendingQuestion.notes = pendingQuestion.notes || [];
    pendingQuestion.notes.push(line);
  }
}

flushQuestion();

fs.writeFileSync(OUTPUT_PATH, JSON.stringify(questions, null, 2), 'utf8');
console.log(`Parsed ${questions.length} questions -> ${OUTPUT_PATH}`);

