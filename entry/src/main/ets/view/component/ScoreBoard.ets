/** Current-score and best-score panel used by the main game page. */
@Component
export struct ScoreBoard {
  @Prop score: number;
  @Prop bestScore: number;
  @Prop panelColor: string = '#BBADA0';

  build() {
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
      .backgroundColor(this.panelColor)
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
      .backgroundColor(this.panelColor)
      .alignItems(HorizontalAlign.Center)
    }
    .width('94%')
  }
}
