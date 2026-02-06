"use client";

interface TimeRangeSelectorProps {
  value: 7 | 14 | 30 | 90;
  onChange: (days: 7 | 14 | 30 | 90) => void;
}

export function TimeRangeSelector({ value, onChange }: TimeRangeSelectorProps) {
  const options: Array<7 | 14 | 30 | 90> = [7, 14, 30, 90];

  return (
    <div className="flex items-center gap-1 bg-gray-800/50 rounded-lg p-0.5">
      {options.map((days) => (
        <button
          key={days}
          onClick={() => onChange(days)}
          className={`px-3 py-1.5 text-sm rounded-md transition-colors ${
            value === days
              ? "bg-blue-600 text-white"
              : "text-gray-400 hover:text-white"
          }`}
        >
          {days}d
        </button>
      ))}
    </div>
  );
}
