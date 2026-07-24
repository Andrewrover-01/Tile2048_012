import { CellPosition, GameStatus, MoveAnimation, SwipeDirection } from '../../model/GameState';
import { GameEngine } from '../../service/GameEngine';
import { scoreManager } from '../../service/ScoreManager';
import { DEFAULT_BOARD_SIZE, EFFECT_ANIMATION_MS, FRAME_INTERVAL_MS, LOG_DOMAIN,
  MOVE_ANIMATION_MS, SWIPE_THRESHOLD } from '../../common/Constants';
import { GameBoard } from '../component/GameBoard';
import { GameOverDialog } from '../component/GameOverDialog';
import { ScoreBoard } from '../component/ScoreBoard';
import { TileRenderer } from '../component/TileRenderer';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct GamePage {
  private engine: GameEngine = new GameEngine();
  private winAcknowledged: boolean = false;
  private panHandled: boolean = false;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private isAnimating: boolean = false;
  private animationTimer: number = -1;

  // The board is rendered on a Canvas and redrawn imperatively after every
  // move. This deliberately avoids ForEach/@Builder reactivity pitfalls that
  // previously left the board and score frozen on the RK3568.
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private tileRenderer: TileRenderer = new TileRenderer();
  private boardReady: boolean = false;

  @State score: number = 0;
  @State bestScore: number = 0;
  @State gameStatus: GameStatus = GameStatus.PLAYING;
  @State isNewRecord: boolean = false;
  @State canUndo: boolean = false;
  @State boardSize: number = DEFAULT_BOARD_SIZE;
  @State animationSpeed: number = 1;
  @State isDarkMode: boolean = false;
  @State colorScheme: number = 0;
  @State settingsVisible: boolean = false;

  aboutToAppear(): void {
    scoreManager.getBestScore().then((best: number) => {
      this.bestScore = best;
    });
  }

  aboutToDisappear(): void {
    this.stopAnimation();
  }

  private startNewGame(): void {
    this.stopAnimation();
    this.engine.init();
    this.winAcknowledged = false;
    this.gameStatus = GameStatus.PLAYING;
    this.isNewRecord = false;
    this.canUndo = false;
    this.score = 0;
    this.drawBoard();
  }

  private undoLastMove(): void {
    this.stopAnimation();
    if (!this.engine.undo()) {
      return;
    }
    this.score = this.engine.getScore();
    this.canUndo = false;
    this.gameStatus = GameStatus.PLAYING;
    this.winAcknowledged = false;
    this.isNewRecord = false;
    this.drawBoard();
  }

  private changeBoardSize(size: number): void {
    if (size === this.boardSize) {
      return;
    }
    this.stopAnimation();
    this.boardSize = size;
    this.engine.setSize(size);
    this.score = 0;
    this.canUndo = false;
    this.gameStatus = GameStatus.PLAYING;
    this.winAcknowledged = false;
    this.isNewRecord = false;
    this.drawBoard();
  }

  private toggleDarkMode(): void {
    this.isDarkMode = !this.isDarkMode;
    this.drawBoard();
  }

  private changeColorScheme(scheme: number): void {
    this.colorScheme = scheme;
    this.drawBoard();
  }

  private processSwipe(direction: SwipeDirection): void {
    if (this.gameStatus !== GameStatus.PLAYING || this.isAnimating) {
      hilog.info(LOG_DOMAIN, 'Tile2048', 'Ignored swipe, status=%{public}d', this.gameStatus);
      return;
    }
    if (!this.engine.move(direction)) {
      return;
    }
    hilog.info(LOG_DOMAIN, 'Tile2048', 'Board moved. direction=%{public}d score=%{public}d', direction, this.engine.getScore());
    this.canUndo = true;
    this.playMoveAnimation(this.engine.getLastMoveAnimation());
  }

  private finishMove(): void {
    this.score = this.engine.getScore();
    this.canUndo = this.engine.canUndo();
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

  private playMoveAnimation(animation: MoveAnimation): void {
    if (animation.motions.length === 0) {
      this.finishMove();
      return;
    }
    this.stopAnimation();
    this.isAnimating = true;
    const startedAt: number = Date.now();
    const moveDuration: number = MOVE_ANIMATION_MS / this.animationSpeed;
    const effectDuration: number = EFFECT_ANIMATION_MS / this.animationSpeed;
    this.animationTimer = setInterval(() => {
      const elapsed: number = Date.now() - startedAt;
      if (elapsed < moveDuration) {
        const progress = this.easeOutCubic(elapsed / moveDuration);
        this.drawMovingTiles(animation, progress);
        return;
      }
      const effectProgress = Math.min(1, (elapsed - moveDuration) / effectDuration);
      this.drawTileEffects(animation, effectProgress);
      if (effectProgress >= 1) {
        this.stopAnimation();
        this.finishMove();
      }
    }, FRAME_INTERVAL_MS);
  }

  private stopAnimation(): void {
    if (this.animationTimer >= 0) {
      clearInterval(this.animationTimer);
      this.animationTimer = -1;
    }
    this.isAnimating = false;
  }

  private easeOutCubic(progress: number): number {
    return 1 - Math.pow(1 - progress, 3);
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
    const padding: number = width * 0.025;
    const gap: number = width * 0.025;
    const cell: number = (width - padding * 2 - gap * (this.boardSize - 1)) / this.boardSize;
    this.drawGridBackground(width, height, padding, gap, cell);
    const grid: number[][] = this.engine.getGrid();
    for (let row = 0; row < this.boardSize; row++) {
      for (let col = 0; col < this.boardSize; col++) {
        const value: number = grid[row][col];
        if (value !== 0) {
          this.drawTile(row, col, value, padding, gap, cell, 1, 1);
        }
      }
    }
  }

  private drawMovingTiles(animation: MoveAnimation, progress: number): void {
    if (!this.boardReady) {
      return;
    }
    const width: number = this.ctx.width;
    const height: number = this.ctx.height;
    const padding: number = width * 0.025;
    const gap: number = width * 0.025;
    const cell: number = (width - padding * 2 - gap * (this.boardSize - 1)) / this.boardSize;
    this.drawGridBackground(width, height, padding, gap, cell);
    for (let motion of animation.motions) {
      const row = motion.fromRow + (motion.toRow - motion.fromRow) * progress;
      const col = motion.fromCol + (motion.toCol - motion.fromCol) * progress;
      this.drawTile(row, col, motion.value, padding, gap, cell, 1, 1);
    }
  }

  private drawTileEffects(animation: MoveAnimation, progress: number): void {
    if (!this.boardReady) {
      return;
    }
    const width: number = this.ctx.width;
    const height: number = this.ctx.height;
    const padding: number = width * 0.025;
    const gap: number = width * 0.025;
    const cell: number = (width - padding * 2 - gap * (this.boardSize - 1)) / this.boardSize;
    const grid: number[][] = this.engine.getGrid();
    this.drawGridBackground(width, height, padding, gap, cell);
    for (let row = 0; row < this.boardSize; row++) {
      for (let col = 0; col < this.boardSize; col++) {
        const value = grid[row][col];
        if (value !== 0 && !this.isCellIn(row, col, animation.mergedCells) &&
          !this.isSameCell(row, col, animation.spawnedCell)) {
          this.drawTile(row, col, value, padding, gap, cell, 1, 1);
        }
      }
    }

    const bounceScale: number = 1 + Math.sin(progress * Math.PI) * 0.16;
    for (let merged of animation.mergedCells) {
      this.drawTile(merged.row, merged.col, grid[merged.row][merged.col], padding, gap, cell, bounceScale, 1);
    }
    if (animation.spawnedCell !== null) {
      const spawned = animation.spawnedCell;
      const appearScale: number = 0.2 + 0.8 * this.easeOutCubic(progress);
      this.drawTile(spawned.row, spawned.col, grid[spawned.row][spawned.col], padding, gap, cell,
        appearScale, progress);
    }
  }

  private drawGridBackground(width: number, height: number, padding: number, gap: number, cell: number): void {
    this.ctx.globalAlpha = 1;
    this.ctx.clearRect(0, 0, width, height);
    this.ctx.fillStyle = this.emptyCellColor();
    for (let row = 0; row < this.boardSize; row++) {
      for (let col = 0; col < this.boardSize; col++) {
        const x = padding + col * (cell + gap);
        const y = padding + row * (cell + gap);
        this.tileRenderer.fillRoundRect(this.ctx, x, y, cell, cell, cell * 0.08);
      }
    }
  }

  private drawTile(row: number, col: number, value: number, padding: number, gap: number, cell: number,
    scale: number, opacity: number): void {
    this.tileRenderer.drawTile(this.ctx, row, col, value, padding, gap, cell, scale, opacity,
      this.colorScheme);
  }

  private isCellIn(row: number, col: number, cells: CellPosition[]): boolean {
    for (let cell of cells) {
      if (cell.row === row && cell.col === col) {
        return true;
      }
    }
    return false;
  }

  private isSameCell(row: number, col: number, cell: CellPosition | null): boolean {
    return cell !== null && cell.row === row && cell.col === col;
  }

  private pageBackgroundColor(): string {
    return this.isDarkMode ? '#121826' : '#FAF8EF';
  }

  private panelBackgroundColor(): string {
    return this.isDarkMode ? '#1D2736' : '#FAF8EF';
  }

  private primaryTextColor(): string {
    return this.isDarkMode ? '#E8EDF5' : '#776E65';
  }

  private secondaryTextColor(): string {
    return this.isDarkMode ? '#AEB8C8' : '#8F7A66';
  }

  private boardBackgroundColor(): string {
    if (this.colorScheme === 1) {
      return this.isDarkMode ? '#27384D' : '#8FAFC4';
    }
    if (this.colorScheme === 2) {
      return this.isDarkMode ? '#29413C' : '#93B8A8';
    }
    return this.isDarkMode ? '#3A414D' : '#BBADA0';
  }

  private emptyCellColor(): string {
    if (this.colorScheme === 1) {
      return this.isDarkMode ? '#344B65' : '#B8CFDC';
    }
    if (this.colorScheme === 2) {
      return this.isDarkMode ? '#35554D' : '#BBD4C9';
    }
    return this.isDarkMode ? '#505865' : '#CDC1B4';
  }

  private actionColor(): string {
    return this.isDarkMode ? '#53677E' : '#8F7A66';
  }

  private selectedColor(selected: boolean): string {
    return selected ? '#ED8C2F' : this.actionColor();
  }

  // ---------------- Overlay ----------------

  @Builder
  private SettingsOverlay() {
    if (this.settingsVisible) {
      Column({ space: 18 }) {
        Row() {
          Text('游戏设置')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.primaryTextColor())
          Blank()
          Button('关闭')
            .fontSize(14)
            .backgroundColor(this.actionColor())
            .fontColor(Color.White)
            .onClick(() => this.settingsVisible = false)
        }
        .width('100%')

        Text('棋盘尺寸（切换后开始新游戏）')
          .fontSize(15)
          .fontColor(this.secondaryTextColor())
          .width('100%')
        Row({ space: 8 }) {
          Button('4 × 4')
            .width('31%')
            .backgroundColor(this.selectedColor(this.boardSize === 4))
            .onClick(() => this.changeBoardSize(4))
          Button('5 × 5')
            .width('31%')
            .backgroundColor(this.selectedColor(this.boardSize === 5))
            .onClick(() => this.changeBoardSize(5))
          Button('6 × 6')
            .width('31%')
            .backgroundColor(this.selectedColor(this.boardSize === 6))
            .onClick(() => this.changeBoardSize(6))
        }
        .width('100%')

        Text('动画速度')
          .fontSize(15)
          .fontColor(this.secondaryTextColor())
          .width('100%')
        Row({ space: 8 }) {
          Button('慢速')
            .width('31%')
            .backgroundColor(this.selectedColor(this.animationSpeed === 0.65))
            .onClick(() => this.animationSpeed = 0.65)
          Button('标准')
            .width('31%')
            .backgroundColor(this.selectedColor(this.animationSpeed === 1))
            .onClick(() => this.animationSpeed = 1)
          Button('快速')
            .width('31%')
            .backgroundColor(this.selectedColor(this.animationSpeed === 1.6))
            .onClick(() => this.animationSpeed = 1.6)
        }
        .width('100%')

        Text('方块颜色')
          .fontSize(15)
          .fontColor(this.secondaryTextColor())
          .width('100%')
        Row({ space: 8 }) {
          Button('经典')
            .width('31%')
            .backgroundColor(this.selectedColor(this.colorScheme === 0))
            .onClick(() => this.changeColorScheme(0))
          Button('海洋')
            .width('31%')
            .backgroundColor(this.selectedColor(this.colorScheme === 1))
            .onClick(() => this.changeColorScheme(1))
          Button('薄荷')
            .width('31%')
            .backgroundColor(this.selectedColor(this.colorScheme === 2))
            .onClick(() => this.changeColorScheme(2))
        }
        .width('100%')

        Button(this.isDarkMode ? '☀️ 切换为浅色模式' : '🌙 切换为黑暗模式')
          .width('100%')
          .backgroundColor(this.isDarkMode ? '#D18A36' : '#3F526A')
          .fontColor(Color.White)
          .onClick(() => this.toggleDarkMode())
      }
      .width('86%')
      .padding(24)
      .borderRadius(18)
      .backgroundColor(this.panelBackgroundColor())
      .alignItems(HorizontalAlign.Start)
      .shadow({ radius: 20, color: '#66000000', offsetX: 0, offsetY: 8 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 20 }) {
        Text('2048')
          .fontSize(52)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .width('94%')

        ScoreBoard({
          score: this.score,
          bestScore: this.bestScore,
          panelColor: this.boardBackgroundColor()
        })

        GameBoard({
          context: this.ctx,
          boardColor: this.boardBackgroundColor(),
          onBoardReady: () => {
            this.boardReady = true;
            this.drawBoard();
          },
          onBoardTouch: (event: TouchEvent) => this.handleBoardTouch(event)
        })

        Row({ space: 8 }) {
          Button('🔄 新游戏')
            .width('31%')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(this.actionColor())
            .borderRadius(6)
            .onClick(() => this.startNewGame())
          Button('↩ 撤销')
            .width('31%')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(this.actionColor())
            .borderRadius(6)
            .enabled(this.canUndo)
            .opacity(this.canUndo ? 1 : 0.45)
            .onClick(() => this.undoLastMove())
          Button('⚙ 设置')
            .width('31%')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor('#ED8C2F')
            .borderRadius(6)
            .onClick(() => this.settingsVisible = true)
        }
        .width('94%')

        Text('在棋盘上向上、下、左、右滑动来移动方块')
          .fontSize(14)
          .fontColor(this.secondaryTextColor())
          .textAlign(TextAlign.Center)
          .width('94%')
      }
      .width('100%')
      .height('100%')
      .padding({ top: 32, bottom: 20 })
      .backgroundColor(this.pageBackgroundColor())
      .alignItems(HorizontalAlign.Center)

      if (this.gameStatus !== GameStatus.PLAYING) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
      }
      GameOverDialog({
        gameStatus: this.gameStatus,
        score: this.score,
        isNewRecord: this.isNewRecord,
        canUndo: this.canUndo,
        panelColor: this.panelBackgroundColor(),
        primaryTextColor: this.primaryTextColor(),
        secondaryTextColor: this.secondaryTextColor(),
        actionColor: this.actionColor(),
        onContinue: () => {
          this.winAcknowledged = true;
          this.gameStatus = GameStatus.PLAYING;
        },
        onUndo: () => this.undoLastMove(),
        onNewGame: () => this.startNewGame()
      })
      if (this.settingsVisible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#77000000')
          .onClick(() => this.settingsVisible = false)
      }
      this.SettingsOverlay()
    }
    .width('100%')
    .height('100%')
  }
}
