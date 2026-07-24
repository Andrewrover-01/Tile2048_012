import { GameStatus, SwipeDirection } from '../model/GameState';
import { GameEngine } from '../service/GameEngine';
import { scoreManager } from '../service/ScoreManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const SWIPE_THRESHOLD: number = 30;
const LOG_DOMAIN: number = 0x0000;
const GRID_SIZE: number = 4;

@Entry
@Component
struct Index {
  private engine: GameEngine = new GameEngine();
  private winAcknowledged: boolean = false;
  private panHandled: boolean = false;
  private touchStartX: number = 0;
  private touchStartY: number = 0;

  // The board is rendered on a Canvas and redrawn imperatively after every
  // move. This deliberately avoids ForEach/@Builder reactivity pitfalls that
  // previously left the board and score frozen on the RK3568.
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private boardReady: boolean = false;

  @State score: number = 0;
  @State bestScore: number = 0;
  @State gameStatus: GameStatus = GameStatus.PLAYING;
  @State isNewRecord: boolean = false;

  aboutToAppear(): void {
    scoreManager.getBestScore().then((best: number) => {
      this.bestScore = best;
    });
  }

  private startNewGame(): void {
    this.engine.init();
    this.winAcknowledged = false;
    this.gameStatus = GameStatus.PLAYING;
    this.isNewRecord = false;
    this.score = 0;
    this.drawBoard();
  }

  private processSwipe(direction: SwipeDirection): void {
    if (this.gameStatus !== GameStatus.PLAYING) {
      hilog.info(LOG_DOMAIN, 'Tile2048', 'Ignored swipe, status=%{public}d', this.gameStatus);
      return;
    }
    if (!this.engine.move(direction)) {
      return;
    }
    hilog.info(LOG_DOMAIN, 'Tile2048', 'Board moved. direction=%{public}d score=%{public}d', direction, this.engine.getScore());
    this.score = this.engine.getScore();
    this.drawBoard();
    if (this.score > this.bestScore) {
      this.bestScore = this.score;
      this.isNewRecord = true;
      scoreManager.saveBestScore(this.score);
    }
    if (this.engine.hasWon() && !this.winAcknowledged) {
      this.gameStatus = GameStatus.WIN;
    } else if (this.engine.isGameOver()) {
      this.gameStatus = GameStatus.GAME_OVER;
    }
  }

  private handleOffset(deltaX: number, deltaY: number): void {
    if (this.panHandled) {
      return;
    }
    if (Math.abs(deltaX) < SWIPE_THRESHOLD && Math.abs(deltaY) < SWIPE_THRESHOLD) {
      return;
    }
    this.panHandled = true;
    if (Math.abs(deltaX) > Math.abs(deltaY)) {
      this.processSwipe(deltaX > 0 ? SwipeDirection.RIGHT : SwipeDirection.LEFT);
    } else {
      this.processSwipe(deltaY > 0 ? SwipeDirection.DOWN : SwipeDirection.UP);
    }
  }

  /** Sole swipe input path, attached to the board Canvas so Down/Move/Up all
   *  report coordinates in the same (board-relative) space. */
  private handleBoardTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down && event.touches.length > 0) {
      this.panHandled = false;
      this.touchStartX = event.touches[0].x;
      this.touchStartY = event.touches[0].y;
      return;
    }
    if (event.type === TouchType.Move && event.touches.length > 0) {
      this.handleOffset(event.touches[0].x - this.touchStartX, event.touches[0].y - this.touchStartY);
      return;
    }
    if (event.type === TouchType.Up && event.changedTouches.length > 0) {
      this.handleOffset(event.changedTouches[0].x - this.touchStartX,
        event.changedTouches[0].y - this.touchStartY);
    }
  }

  // ---------------- Canvas drawing ----------------

  private drawBoard(): void {
    if (!this.boardReady) {
      return;
    }
    const width: number = this.ctx.width;
    const height: number = this.ctx.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, width, height);
    const padding: number = width * 0.025;
    const gap: number = width * 0.025;
    const cell: number = (width - padding * 2 - gap * (GRID_SIZE - 1)) / GRID_SIZE;
    const grid: number[][] = this.engine.getGrid();
    for (let row = 0; row < GRID_SIZE; row++) {
      for (let col = 0; col < GRID_SIZE; col++) {
        const x: number = padding + col * (cell + gap);
        const y: number = padding + row * (cell + gap);
        const value: number = grid[row][col];
        this.ctx.fillStyle = value === 0 ? '#CDC1B4' : this.tileColor(value);
        this.fillRoundRect(x, y, cell, cell, cell * 0.08);
        if (value !== 0) {
          this.ctx.fillStyle = this.tileTextColor(value);
          this.ctx.font = this.tileFont(value, cell);
          this.ctx.textAlign = 'center';
          this.ctx.textBaseline = 'middle';
          this.ctx.fillText(value.toString(), x + cell / 2, y + cell / 2);
        }
      }
    }
  }

  private fillRoundRect(x: number, y: number, w: number, h: number, r: number): void {
    this.ctx.beginPath();
    this.ctx.moveTo(x + r, y);
    this.ctx.arcTo(x + w, y, x + w, y + h, r);
    this.ctx.arcTo(x + w, y + h, x, y + h, r);
    this.ctx.arcTo(x, y + h, x, y, r);
    this.ctx.arcTo(x, y, x + w, y, r);
    this.ctx.closePath();
    this.ctx.fill();
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

  private tileColor(value: number): string {
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

  private tileTextColor(value: number): string {
    return value === 2 || value === 4 ? '#776E65' : '#F9F6F2';
  }

  // ---------------- Overlay ----------------

  @Builder
  private ResultOverlay() {
    if (this.gameStatus !== GameStatus.PLAYING) {
      Column({ space: 14 }) {
        Text(this.gameStatus === GameStatus.WIN ? '🎉 你赢了！' : '游戏结束！')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#776E65')
        Text(this.gameStatus === GameStatus.WIN ? '合成 2048，继续挑战吧！' : '本局得分')
          .fontSize(17)
          .fontColor('#776E65')
        Text(this.score.toString())
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ED8C2F')
        if (this.isNewRecord) {
          Text('🆕 新纪录！')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E77D27')
        }
        if (this.gameStatus === GameStatus.WIN) {
          Button('继续挑战')
            .width('80%')
            .backgroundColor('#8F7A66')
            .fontColor(Color.White)
            .onClick(() => {
              this.winAcknowledged = true;
              this.gameStatus = GameStatus.PLAYING;
            })
        }
        Button('🔄 ' + (this.gameStatus === GameStatus.WIN ? '新游戏' : '再来一局'))
          .width('80%')
          .backgroundColor('#ED8C2F')
          .fontColor(Color.White)
          .onClick(() => this.startNewGame())
      }
      .width('76%')
      .padding(24)
      .borderRadius(18)
      .backgroundColor('#FAF8EF')
      .alignItems(HorizontalAlign.Center)
      .shadow({ radius: 20, color: '#66000000', offsetX: 0, offsetY: 8 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 20 }) {
        Text('2048')
          .fontSize(52)
          .fontWeight(FontWeight.Bold)
          .fontColor('#776E65')
          .width('94%')

        Row() {
          Column() {
            Text('SCORE')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#EEE4DA')
            Text(this.score.toString())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ top: 1 })
          }
          .width('46%')
          .padding({ top: 7, bottom: 7 })
          .borderRadius(6)
          .backgroundColor('#BBADA0')
          .alignItems(HorizontalAlign.Center)

          Blank()

          Column() {
            Text('BEST')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#EEE4DA')
            Text(this.bestScore.toString())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ top: 1 })
          }
          .width('46%')
          .padding({ top: 7, bottom: 7 })
          .borderRadius(6)
          .backgroundColor('#BBADA0')
          .alignItems(HorizontalAlign.Center)
        }
        .width('94%')

        Canvas(this.ctx)
          .width('94%')
          .aspectRatio(1)
          .backgroundColor('#BBADA0')
          .borderRadius(10)
          .onReady(() => {
            this.boardReady = true;
            this.drawBoard();
          })
          .onTouch((event: TouchEvent) => this.handleBoardTouch(event))

        Button('🔄 新游戏')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#8F7A66')
          .borderRadius(6)
          .padding({ left: 22, right: 22, top: 10, bottom: 10 })
          .onClick(() => this.startNewGame())

        Text('在棋盘上向上、下、左、右滑动来移动方块')
          .fontSize(14)
          .fontColor('#776E65')
          .textAlign(TextAlign.Center)
          .width('94%')
      }
      .width('100%')
      .height('100%')
      .padding({ top: 32, bottom: 20 })
      .backgroundColor('#FAF8EF')
      .alignItems(HorizontalAlign.Center)

      if (this.gameStatus !== GameStatus.PLAYING) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
      }
      this.ResultOverlay()
    }
    .width('100%')
    .height('100%')
  }
}
