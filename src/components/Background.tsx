import { useEffect, useRef } from 'react';
import { useStore } from '@/store/useStore';

/**
 * Живой фон: три «авроры» на CSS-анимации + слой частиц на canvas.
 * Работает на всех платформах и легко гасится настройкой «анимации».
 */
export function Background() {
  const animations = useStore((s) => s.settings.animations);
  const accent = useStore((s) => s.settings.accent);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !animations) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let raf = 0;
    let width = 0;
    let height = 0;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const particles: { x: number; y: number; vx: number; vy: number; r: number; a: number; hue: number }[] = [];

    const resize = () => {
      width = canvas.clientWidth;
      height = canvas.clientHeight;
      canvas.width = width * dpr;
      canvas.height = height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      particles.length = 0;
      const count = Math.round((width * height) / 26000);
      for (let i = 0; i < count; i++) {
        particles.push({
          x: Math.random() * width,
          y: Math.random() * height,
          vx: (Math.random() - 0.5) * 0.18,
          vy: -0.06 - Math.random() * 0.22,
          r: 0.6 + Math.random() * 1.7,
          a: 0.08 + Math.random() * 0.35,
          hue: Math.random(),
        });
      }
    };

    const draw = () => {
      ctx.clearRect(0, 0, width, height);
      for (const p of particles) {
        p.x += p.vx;
        p.y += p.vy;
        if (p.y < -6) {
          p.y = height + 6;
          p.x = Math.random() * width;
        }
        if (p.x < -6) p.x = width + 6;
        if (p.x > width + 6) p.x = -6;
        const grad = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r * 5);
        const color = p.hue > 0.5 ? '160, 220, 255' : '190, 170, 255';
        grad.addColorStop(0, `rgba(${color}, ${p.a})`);
        grad.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r * 5, 0, Math.PI * 2);
        ctx.fill();
      }
      raf = requestAnimationFrame(draw);
    };

    resize();
    draw();
    window.addEventListener('resize', resize);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', resize);
    };
  }, [animations]);

  return (
    <div className="aurora" aria-hidden>
      <div
        className="aurora-blob"
        style={{
          width: '48vw',
          height: '48vw',
          left: '-8vw',
          top: '-14vh',
          background: `radial-gradient(circle at 40% 40%, var(--accent), transparent 68%)`,
          animation: 'float 22s ease-in-out infinite',
          opacity: 0.38,
        }}
      />
      <div
        className="aurora-blob"
        style={{
          width: '40vw',
          height: '40vw',
          right: '-6vw',
          top: '4vh',
          background: `radial-gradient(circle at 60% 40%, var(--accent-2), transparent 66%)`,
          animation: 'float 27s ease-in-out infinite reverse',
          opacity: 0.28,
        }}
      />
      <div
        className="aurora-blob"
        style={{
          width: '52vw',
          height: '36vw',
          left: '18vw',
          bottom: '-18vh',
          background: 'radial-gradient(circle at 50% 50%, #4c1d95, transparent 70%)',
          animation: 'float 33s ease-in-out infinite',
          opacity: 0.3,
        }}
      />
      <canvas ref={canvasRef} className="absolute inset-0 h-full w-full" />
      <div className="aurora-grid" />
      <div className="aurora-noise" />
      <div className="aurora-vignette" />
      <div key={accent} className="pointer-events-none absolute inset-0 transition-opacity duration-700" />
    </div>
  );
}
