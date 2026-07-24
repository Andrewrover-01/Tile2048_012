import { GameStatus } from '../../model/GameState';

/** Shared result dialog for both game-over and 2048 victory states. */
@Component
export struct GameOverDialog {
  @Prop gameStatus: GameStatus;
  @Prop score: number;
  @Prop isNewRecord: boolean;
  @Prop canUndo: boolean;
  @Prop panelColor: string;
  @Prop primaryTextColor: string;
  @Prop secondaryTextColor: string;
  @Prop actionColor: string;
  onContinue: () => void = () => {};
  onUndo: () => void = () => {};
  onNewGame: () => void = () => {};

  build() {
    if (this.gameStatus !== GameStatus.PLAYING) {
      Column({ space: 14 }) {
        Text(this.gameStatus === GameStatus.WIN ? '🎉 你赢了！' : '游戏结束！')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor)
        Text(this.gameStatus === GameStatus.WIN ? '合成 2048，继续挑战吧！' : '本局得分')
          .fontSize(17)
          .fontColor(this.secondaryTextColor)
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
            .backgroundColor(this.actionColor)
            .fontColor(Color.White)
            .onClick(() => this.onContinue())
        }
        if (this.canUndo) {
          Button('↩ 撤销一步')
            .width('80%')
            .backgroundColor(this.actionColor)
            .fontColor(Color.White)
            .onClick(() => this.onUndo())
        }
        Button('🔄 ' + (this.gameStatus === GameStatus.WIN ? '新游戏' : '再来一局'))
          .width('80%')
          .backgroundColor('#ED8C2F')
          .fontColor(Color.White)
          .onClick(() => this.onNewGame())
      }
      .width('76%')
      .padding(24)
      .borderRadius(18)
      .backgroundColor(this.panelColor)
      .alignItems(HorizontalAlign.Center)
      .shadow({ radius: 20, color: '#66000000', offsetX: 0, offsetY: 8 })
    }
  }
}
