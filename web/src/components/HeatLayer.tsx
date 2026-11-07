import { useEffect } from 'react';
import { useMap } from 'react-leaflet';
import type { HeatCell } from '../api/operations';

export function HeatLayer({ cells }: { cells: HeatCell[] }) {
  const map = useMap();
  useEffect(() => {
    const canvas = document.createElement('canvas');
    canvas.className = 'pointer-events-none absolute inset-0 z-[450] opacity-70';
    map.getContainer().append(canvas);
    const draw = () => {
      const size = map.getSize(); canvas.width = size.x; canvas.height = size.y;
      const context = canvas.getContext('2d', { willReadFrequently: true }); if (!context) return;
      const maximum = Math.max(1, ...cells.map(cell => cell.count));
      for (const cell of cells) {
        const point = map.latLngToContainerPoint([cell.latitude, cell.longitude]);
        const radius = 35;
        const gradient = context.createRadialGradient(point.x, point.y, 0, point.x, point.y, radius);
        gradient.addColorStop(0, `rgba(0,0,0,${Math.max(.12, cell.count / maximum)})`);
        gradient.addColorStop(1, 'rgba(0,0,0,0)');
        context.fillStyle = gradient; context.fillRect(point.x-radius, point.y-radius, radius*2, radius*2);
      }
      const pixels = context.getImageData(0, 0, size.x, size.y);
      for (let i = 0; i < pixels.data.length; i += 4) {
        const intensity = pixels.data[i+3] / 255;
        pixels.data[i] = Math.min(255, intensity * 510);
        pixels.data[i+1] = Math.max(0, 255 - Math.abs(intensity - .5) * 510);
        pixels.data[i+2] = Math.max(0, 255 - intensity * 510);
      }
      context.putImageData(pixels, 0, 0);
    };
    draw(); map.on('move zoom resize', draw);
    return () => { map.off('move zoom resize', draw); canvas.remove(); };
  }, [cells, map]);
  return null;
}
