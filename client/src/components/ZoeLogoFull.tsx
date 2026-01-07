export default function ZoeLogoFull({ className = "", height = 40 }: { className?: string; height?: number }) {
  return (
    <img
      src="/zoe-logo-full.svg"
      alt="Zoé Sleep"
      height={height}
      className={className}
      style={{ height: `${height}px`, width: 'auto' }}
    />
  );
}
