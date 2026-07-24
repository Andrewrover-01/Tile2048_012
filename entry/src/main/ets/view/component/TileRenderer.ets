/** Canvas drawing helper responsible for tile geometry, colors and text. */
export class TileRenderer {
  drawTile(context: CanvasRenderingContext2D, row: number, col: number, value: number,
    padding: number, gap: number, cell: number, scale: number, opacity: number,
    colorScheme: number): void {
    const size: number = cell * scale;
    const centerX: number = padding + col * (cell + gap) + cell / 2;
    const centerY: number = padding + row * (cell + gap) + cell / 2;
    const x: number = centerX - size / 2;
    const y: number = centerY - size / 2;
    context.globalAlpha = opacity;
    context.fillStyle = this.tileColor(value, colorScheme);
    this.fillRoundRect(context, x, y, size, size, size * 0.08);
    context.fillStyle = this.tileTextColor(value, colorScheme);
    context.font = this.tileFont(value, size);
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillText(value.toString(), centerX, centerY);
    context.globalAlpha = 1;
  }

  fillRoundRect(context: CanvasRenderingContext2D, x: number, y: number,
    width: number, height: number, radius: number): void {
    context.beginPath();
    context.moveTo(x + radius, y);
    context.arcTo(x + width, y, x + width, y + height, radius);
    context.arcTo(x + width, y + height, x, y + height, radius);
    context.arcTo(x, y + height, x, y, radius);
    context.arcTo(x, y, x + width, y, radius);
    context.closePath();
    context.fill();
  }

  private tileFont(value: number, cell: number): string {
    let ratio: number = 0.45;
    if (value >= 100) {
      ratio = 0.36;
    }
    if (value >= 1000) {
      ratio = 0.28;
    }
    return 'bold ' + (cell * ratio).toFixed(1) + 'px sans-serif';
  }

  private tileColor(value: number, colorScheme: number): string {
    if (colorScheme === 1) {
      if (value === 2) return '#D9F0FA';
      if (value === 4) return '#BFE3F2';
      if (value === 8) return '#72C6E8';
      if (value === 16) return '#42ACD6';
      if (value === 32) return '#258EC2';
      if (value === 64) return '#1976A8';
      if (value === 128) return '#5B8DEF';
      if (value === 256) return '#536DCE';
      if (value === 512) return '#6657C8';
      if (value === 1024) return '#7B4BB7';
      if (value === 2048) return '#933FA4';
      return '#273C75';
    }
    if (colorScheme === 2) {
      if (value === 2) return '#E0F4EA';
      if (value === 4) return '#C6E9D8';
      if (value === 8) return '#8FD3B6';
      if (value === 16) return '#62BF9C';
      if (value === 32) return '#3DAA82';
      if (value === 64) return '#24906B';
      if (value === 128) return '#A8C85A';
      if (value === 256) return '#D0C84E';
      if (value === 512) return '#E5B84A';
      if (value === 1024) return '#E89A48';
      if (value === 2048) return '#E77A55';
      return '#275D50';
    }
    if (value === 2) return '#EEE4DA';
    if (value === 4) return '#EDE0C8';
    if (value === 8) return '#F2B179';
    if (value === 16) return '#F59563';
    if (value === 32) return '#F67C5F';
    if (value === 64) return '#F65E3B';
    if (value === 128) return '#EDCF72';
    if (value === 256) return '#EDCC61';
    if (value === 512) return '#EDC850';
    if (value === 1024) return '#EDC53F';
    if (value === 2048) return '#EDC22E';
    return '#3C3A32';
  }

  private tileTextColor(value: number, colorScheme: number): string {
    if (value === 2 || value === 4) {
      return colorScheme === 0 ? '#776E65' : '#35505D';
    }
    return '#F9F6F2';
  }
}
