import { common } from '@kit.AbilityKit';
import { inputMethodEngine } from '@kit.IMEKit';
import {
  ArcButton,ArcButtonOptions,ArcButtonPosition,ArcButtonStyleMode,ArcList,ArcListAttribute,ArcListItem,ArcListItemAttribute} from '@kit.ArkUI';
import { ContextAction, DemoPhotoChoice, LabSection,  WebInteractionState} from '../model/WebInteractionState';
import { WebInteractionViewModel } from '../viewmodel/WebInteractionViewModel';

@Entry
@Component
struct Index {
  @State private uiState: WebInteractionState =
    new WebInteractionState();
  private viewModel: WebInteractionViewModel =
    new WebInteractionViewModel(this.uiState);

  aboutToDisappear(): void {
    this.viewModel.dispose();
  }

  private getHeaderTitle(): string {
    let title: string = 'WEB LAB';
    switch (this.uiState.currentSection) {
      case LabSection.FILE:
        title = 'FILE';
        break;
      case LabSection.KEYBOARD:
        title = 'KEYBOARD';
        break;
      case LabSection.CONTEXT_MENU:
        title = 'CONTEXT';
        break;
      case LabSection.COOKIE_AND_POST:
        title = 'COOKIE & POST';
        break;
      default:
        break;
    }
    return this.uiState.guidedMode
      ? `${this.uiState.guidedStep + 1}/4 ${title}`
      : title;
  }

  private handlePrimaryAction(): void {
    if (this.uiState.currentSection === LabSection.COOKIE_AND_POST) {
      this.viewModel.refresh();
      return;
    }
    this.viewModel.nextSection();
  }

  @Builder
  private featureMenuItem(
    title: string,
    caption: string,
    section: LabSection
  ) {
    Row() {
      Column({ space: 1 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F8FAFC')
        Text(caption)
          .fontSize(9)
          .fontColor('#94A3B8')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('94%')
    .height(44)
    .padding({ left: 15, right: 15 })
    .borderRadius(22)
    .backgroundColor('#15243A')
    .border({ width: 1, color: '#28405F' })
    .onClick(() => {
      if (section === LabSection.HOME) {
        this.viewModel.startGuidedDemo();
      } else {
        this.viewModel.openSection(section);
      }
    })
  }

  @Builder
  private homeMenu() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 1 }) {
        Text('WEB FILE KEYBOARD')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E0F2FE')
          .letterSpacing(0.8)
          .margin({ top: 28 })

        Text(this.uiState.status ===
          'Guided demo complete - all four features explored'
          ? 'GUIDED DEMO COMPLETE'
          : 'CHOOSE A FEATURE')
          .fontSize(8)
          .fontWeight(FontWeight.Medium)
          .fontColor('#7DD3FC')
          .letterSpacing(0.8)
          .margin({ top: 4 })

        ArcList({ initialIndex: 1 }) {
          ArcListItem() {
            this.featureMenuItem(
              'Guided Demo',
              'Try every feature step by step',
              LabSection.HOME
            );
          }
          .height(47)
          .autoScale(true)

          ArcListItem() {
            this.featureMenuItem(
              'File Selection',
              'MIME, capture, multiple files',
              LabSection.FILE
            );
          }
          .height(47)
          .autoScale(true)

          ArcListItem() {
            this.featureMenuItem(
              'Custom Keyboard',
              'Wearable text controls',
              LabSection.KEYBOARD
            );
          }
          .height(47)
          .autoScale(true)

          ArcListItem() {
            this.featureMenuItem(
              'Context Menu',
              'Copy, select, and find',
              LabSection.CONTEXT_MENU
            );
          }
          .height(47)
          .autoScale(true)

          ArcListItem() {
            this.featureMenuItem(
              'Cookie & POST',
              'Cookie and form resubmission',
              LabSection.COOKIE_AND_POST
            );
          }
          .height(47)
          .autoScale(true)
        }
        .width('76%')
        .height(150)
        .scrollBar(BarState.Off)
        .enableScrollInteraction(true)
        .fadingEdge(false)
        .clip(true)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#07111F')
  }

  @Builder
  private customKeyboardBuilder() {
    Column({ space: 4 }) {
      Text('Quick comment')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#E2E8F0')

      Row({ space: 6 }) {
        Button('Hello')
          .fontSize(10)
          .height(32)
          .padding({ left: 2, right: 2 })
          .layoutWeight(1)
          .onClick(() => this.viewModel.insertKeyboardText('Hello '))
        Button('Great')
          .fontSize(10)
          .height(32)
          .padding({ left: 2, right: 2 })
          .layoutWeight(1)
          .onClick(() => this.viewModel.insertKeyboardText('Great '))
        Button('Nice')
          .fontSize(10)
          .height(32)
          .padding({ left: 2, right: 2 })
          .layoutWeight(1)
          .onClick(() => this.viewModel.insertKeyboardText('Nice '))
      }
      .width('80%')

      Row({ space: 6 }) {
        Button('Space')
          .fontSize(9)
          .height(28)
          .padding({ left: 2, right: 2 })
          .layoutWeight(1)
          .onClick(() => this.viewModel.insertKeyboardText(' '))
        Button('Delete')
          .fontSize(9)
          .height(28)
          .padding({ left: 2, right: 2 })
          .layoutWeight(1)
          .onClick(() => this.viewModel.deleteKeyboardText())
        Button('Done')
          .fontSize(9)
          .height(28)
          .padding({ left: 2, right: 2 })
          .layoutWeight(1)
          .onClick(() => this.viewModel.finishKeyboard(
            inputMethodEngine.ENTER_KEY_TYPE_DONE
          ))
      }
      .width('60%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 12, right: 12, top: 6, bottom: 30 })
    .backgroundColor('#101C2D')
  }

  @Builder
  private filePickerOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 8 }) {
        Text('Wearable photo picker')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
          .margin({ top: 20 })

        Text(this.uiState.fileParameters)
          .fontSize(10)
          .fontColor('#94A3B8')
          .maxLines(2)
          .textAlign(TextAlign.Center)

        ArcList() {
          ArcListItem() {
            Row({ space: 10 }) {
              Image($rawfile('sample_sky.svg'))
                .width(38)
                .height(38)
                .borderRadius(12)
              Text('Sky')
                .fontSize(14)
                .fontColor('#F8FAFC')
            }
            .width('100%')
            .height(50)
            .padding({ left: 10 })
            .borderRadius(16)
            .backgroundColor('#1E3A5F')
            .onClick(() =>
            this.viewModel.selectDemoPhotos(DemoPhotoChoice.SKY))
          }
          .height(54)

          ArcListItem() {
            Row({ space: 10 }) {
              Image($rawfile('sample_leaf.svg'))
                .width(38)
                .height(38)
                .borderRadius(12)
              Text('Leaf')
                .fontSize(14)
                .fontColor('#F8FAFC')
            }
            .width('100%')
            .height(50)
            .padding({ left: 10 })
            .borderRadius(16)
            .backgroundColor('#1E3A5F')
            .onClick(() =>
            this.viewModel.selectDemoPhotos(DemoPhotoChoice.LEAF))
          }
          .height(54)

          if (this.uiState.fileMultipleAllowed) {
            ArcListItem() {
              Button('Select both')
                .width('100%')
                .height(48)
                .fontSize(14)
                .onClick(() =>
                this.viewModel.selectDemoPhotos(DemoPhotoChoice.BOTH))
            }
            .height(52)
          }

          ArcListItem() {
            Button('Cancel')
              .width('100%')
              .height(48)
              .fontSize(14)
              .onClick(() =>
              this.viewModel.selectDemoPhotos(DemoPhotoChoice.CANCEL))
          }
          .height(52)
        }
        .width('100%')
        .height(150)
        .scrollBar(BarState.Off)
      }
      .width('88%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 24, right: 24, top: 18, bottom: 8 })
      .borderRadius(36)
      .backgroundColor('#15243A')
      .border({ width: 1, color: '#334155' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#D907111F')
  }

  @Builder
  private contextMenuOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 8 }) {
        Text(this.uiState.contextTitle)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('78%')
          .textAlign(TextAlign.Center)
          .margin({ top: 20 })

        Text(this.uiState.contextDetails)
          .fontSize(11)
          .fontColor('#94A3B8')
          .maxLines(1)

        ArcList() {
          ArcListItem() {
            Button('Copy')
              .width('92%')
              .height(48)
              .fontSize(14)
              .padding(0)
              .onClick(() =>
              this.viewModel.performContextAction(ContextAction.COPY))
          }
          .height(52)

          ArcListItem() {
            Button('Select all')
              .width('92%')
              .height(48)
              .fontSize(14)
              .padding(0)
              .onClick(() =>
              this.viewModel.performContextAction(ContextAction.SELECT_ALL))
          }
          .height(52)

          ArcListItem() {
            Button('Find on page')
              .width('92%')
              .height(48)
              .fontSize(14)
              .padding(0)
              .onClick(() =>
              this.viewModel.performContextAction(ContextAction.LOOK_UP))
          }
          .height(52)

          ArcListItem() {
            Button('Close')
              .width('92%')
              .height(48)
              .fontSize(14)
              .padding(0)
              .onClick(() =>
              this.viewModel.performContextAction(ContextAction.CLOSE))
          }
          .height(52)
        }
        .width('100%')
        .height(145)
        .scrollBar(BarState.Off)
      }
      .width('78%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16, top: 18, bottom: 10 })
      .borderRadius(34)
      .backgroundColor('#15243A')
      .border({ width: 1, color: '#334155' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#D907111F')
  }

  @Builder
  private resubmissionOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 8 }) {
        Text('Resend form?')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F8FAFC')
          .margin({ top: 20 })

        Text('POST data will be sent again when the page refreshes.')
          .fontSize(12)
          .fontColor('#94A3B8')
          .width('78%')
          .textAlign(TextAlign.Center)
          .maxLines(2)

        ArcList() {
          ArcListItem() {
            Button('Resend')
              .width('92%')
              .height(42)
              .fontSize(13)
              .padding(0)
              .onClick(() => this.viewModel.resolveResubmission(true))
          }
          .height(46)
          .autoScale(false)

          ArcListItem() {
            Button('Cancel')
              .width('92%')
              .height(42)
              .fontSize(13)
              .padding(0)
              .onClick(() => this.viewModel.resolveResubmission(false))
          }
          .height(46)
          .autoScale(false)
        }
        .width('100%')
        .height(140)
        .scrollBar(BarState.Off)
        .enableScrollInteraction(false)
        .clip(true)
        .translate({ y: -50 })
      }
      .width('88%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 24, right: 24, top: 24, bottom: 8 })
      .borderRadius(34)
      .backgroundColor('#15243A')
      .border({ width: 1, color: '#334155' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#D907111F')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 2 }) {
        Row({ space: 8 }) {
          Button('Menu')
            .width(50)
            .height(22)
            .fontSize(10)
            .padding(0)
            .fontColor('#BAE6FD')
            .backgroundColor('#172554')
            .onClick(() => this.viewModel.openMenu())

          Text(this.getHeaderTitle())
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E0F2FE')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('60%')
        .margin({ top: 32 })

        Text(this.uiState.status)
          .fontSize(10)
          .fontColor('#7DD3FC')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('80%')
          .textAlign(TextAlign.Center)

        Text(`Cookie: ${this.uiState.cookieValue}`)
          .fontSize(9)
          .fontColor('#94A3B8')
          .maxLines(1)

        Web({ src: '', controller: this.viewModel.controller })
          .width('92%')
          .height(140)
          .borderRadius(30)
          .backgroundColor('#F8FAFC')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .zoomAccess(true)
          .fileAccess(false)
          .geolocationAccess(false)
          .onControllerAttached(() => {
            const context: common.Context =
              this.getUIContext().getHostContext() as common.Context;
            this.viewModel.onControllerAttached(context);
          })
          .onPageEnd((event) => this.viewModel.onPageEnd(event.url))
          .onErrorReceive((event) => this.viewModel.onPageError(
            event.error.getErrorCode(),
            event.error.getErrorInfo(),
            event.request.getRequestUrl(),
            event.request.isMainFrame()
          ))
          .onInterceptRequest((event) =>
          this.viewModel.interceptRequest(event.request) as WebResourceResponse)
          .onShowFileSelector((event) =>
          this.viewModel.onShowFileSelector(
            event.fileSelector,
            event.result
          ))
          .onInterceptKeyboardAttach((info) => {
            const options: WebKeyboardOptions = {
              useSystemKeyboard: true
            };
            if (info.attributes['data-keyboard'] === 'wearable') {
              this.viewModel.attachKeyboard(info.controller, info.attributes);
              options.useSystemKeyboard = false;
              options.customKeyboard = () => {
                this.customKeyboardBuilder();
              };
            }
            return options;
          })
          .onContextMenuShow((event) =>
          this.viewModel.onContextMenuShow(event.param, event.result))
          .onContextMenuHide(() => this.viewModel.onContextMenuHidden())
          .onSearchResultReceive((event) =>
          this.viewModel.onSearchResult(
            event.numberOfMatches,
            event.isDoneCounting
          ))
          .onDataResubmitted((event) =>
          this.viewModel.onDataResubmitted(event.handler))
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#07111F')

      if (this.uiState.menuVisible) {
        this.homeMenu();
      }

      if (!this.uiState.menuVisible) {
        Stack({ alignContent: Alignment.Bottom }) {
          if (this.uiState.currentSection === LabSection.COOKIE_AND_POST) {
            ArcButton({
              options: new ArcButtonOptions({
                label: 'Refresh',
                position: ArcButtonPosition.BOTTOM_EDGE,
                styleMode: ArcButtonStyleMode.EMPHASIZED_LIGHT,
                onClick: () => this.handlePrimaryAction()
              })
            })
          } else {
            ArcButton({
              options: new ArcButtonOptions({
                label: 'Next',
                position: ArcButtonPosition.BOTTOM_EDGE,
                styleMode: ArcButtonStyleMode.EMPHASIZED_LIGHT,
                onClick: () => this.handlePrimaryAction()
              })
            })
          }
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.uiState.filePickerVisible) {
        this.filePickerOverlay();
      }

      if (this.uiState.contextMenuVisible) {
        this.contextMenuOverlay();
      }

      if (this.uiState.resubmissionVisible) {
        this.resubmissionOverlay();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#07111F')
  }
}
