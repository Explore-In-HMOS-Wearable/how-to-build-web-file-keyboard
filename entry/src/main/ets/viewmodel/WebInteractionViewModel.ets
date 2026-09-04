import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ContextAction, DemoPhotoChoice, LabSection, WebInteractionState } from '../model/WebInteractionState';

const LOG_DOMAIN: number = 0x0000;
const LOG_TAG: string = 'WearWebLab';
const DEMO_ORIGIN: string = 'xxxxxx'; // Add your url
const SUBMIT_URL: string = `${DEMO_ORIGIN}/submit`;
const COOKIE_NAME: string = 'labSession';
const GUIDED_SECTIONS: Array<LabSection> = [
  LabSection.FILE,
  LabSection.KEYBOARD,
  LabSection.CONTEXT_MENU,
  LabSection.COOKIE_AND_POST
];
const POST_RESULT_HTML: string = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <link rel="icon" href="data:,">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    body{margin:0;padding:14px 18px 100px;background:#f8fafc;color:#10233f;
      font-family:system-ui,sans-serif;text-align:center}
    .mark{width:64px;height:34px;margin:0 auto 8px;border-radius:12px;
      background:#dcfce7;color:#15803d;font-size:14px;font-weight:700;line-height:34px}
    h1{margin:0 0 4px;font-size:18px}
    p{margin:0;color:#52647e;font-size:12px;line-height:1.4}
  </style>
</head>
<body>
  <div class="mark">Done</div>
  <h1>Form received locally</h1>
  <p>Tap the Refresh button below to try DataResubmissionHandler.</p>
</body>
</html>`;

@Observed
export class WebInteractionViewModel {
  readonly controller: webview.WebviewController = new webview.WebviewController();
  readonly state: WebInteractionState;

  private attached: boolean = false;
  private keyboardController: WebKeyboardController | undefined = undefined;
  private contextMenuResult: WebContextMenuResult | undefined = undefined;
  private resubmissionHandler: DataResubmissionHandler | undefined = undefined;
  private fileSelectorResult: FileSelectorResult | undefined = undefined;
  private samplePhotoUris: Array<string> = [];
  private selectedText: string = '';
  private linkUrl: string = '';
  private sourceUrl: string = '';
  private contextHasImage: boolean = false;
  private ignoreNextContextMenuHide: boolean = false;
  private localFormHtml: string = '';
  private pageReady: boolean = false;
  private postResultVisible: boolean = false;

  constructor(state: WebInteractionState) {
    this.state = state;
  }

  onControllerAttached(context: common.Context): void {
    if (this.attached) {
      return;
    }
    this.attached = true;

    try {
      this.prepareCookie();
      this.prepareSamplePhotos(context);
      const bytes: Uint8Array =
        context.resourceManager.getRawFileContentSync('upload_demo.html');
      this.localFormHtml =
        new util.TextDecoder('utf-8').decodeToString(bytes);
      if (!this.loadLocalForm()) {
        this.attached = false;
        return;
      }
      this.state.status = 'Loading web form';
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Local form loaded with base origin');
    } catch (error) {
      this.attached = false;
      this.reportError('Loading web form', error as Object);
    }
  }

  onPageEnd(url: string): void {
    this.pageReady = true;
    this.postResultVisible = url === SUBMIT_URL;
    if (this.state.currentSection === LabSection.HOME) {
      this.state.status = 'Choose a feature or start the guided demo';
    } else {
      this.state.status = this.getSectionInstruction(this.state.currentSection);
      if (!this.postResultVisible) {
        this.scrollToSection(this.state.currentSection);
      }
    }
    const displayUrl: string = url.startsWith('data:')
      ? 'data:text/html (local form)'
      : this.shorten(url, 96);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Page loaded. url=%{public}s', displayUrl);
  }

  onPageError(
    code: number,
    message: string,
    url: string,
    mainFrame: boolean
  ): void {
    if (mainFrame) {
      this.pageReady = false;
      this.state.status = `Page error ${code}`;
    }
    hilog.error(
      LOG_DOMAIN,
      LOG_TAG,
      'Page error. code=%{public}d main=%{public}s url=%{public}s message=%{public}s',
      code,
      mainFrame.toString(),
      url,
      message
    );
  }

  interceptRequest(request: WebResourceRequest): WebResourceResponse | null {
    const url: string = request.getRequestUrl();
    if (url !== SUBMIT_URL) {
      return null;
    }

    const response: WebResourceResponse = new WebResourceResponse();
    response.setResponseData(POST_RESULT_HTML);
    response.setResponseEncoding('UTF-8');
    response.setResponseMimeType('text/html');
    response.setResponseCode(200);
    response.setReasonMessage('OK');
    hilog.info(
      LOG_DOMAIN,
      LOG_TAG,
      'Local form response. method=%{public}s url=%{public}s',
      request.getRequestMethod(),
      url
    );
    return response;
  }

  startGuidedDemo(): void {
    this.state.guidedMode = true;
    this.state.guidedStep = 0;
    this.openSection(GUIDED_SECTIONS[0]);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Guided demo started');
  }

  openSection(section: LabSection): void {
    this.state.currentSection = section;
    this.state.menuVisible = false;
    this.state.status = this.getSectionInstruction(section);

    if (this.postResultVisible) {
      this.loadLocalForm();
      return;
    }
    this.scrollToSection(section);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Lab section opened. section=%{public}s', section);
  }

  nextSection(): void {
    const currentIndex: number = GUIDED_SECTIONS.indexOf(this.state.currentSection);
    const nextIndex: number = currentIndex + 1;
    if (nextIndex >= GUIDED_SECTIONS.length) {
      this.completeGuidedDemo();
      return;
    }
    if (this.state.guidedMode) {
      this.state.guidedStep = nextIndex;
    }
    this.openSection(GUIDED_SECTIONS[nextIndex]);
  }

  openMenu(): void {
    this.state.currentSection = LabSection.HOME;
    this.state.menuVisible = true;
    this.state.guidedMode = false;
    this.state.guidedStep = 0;
    this.state.status = 'Choose a feature or start the guided demo';
    try {
      this.controller.clearMatches();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Search clear while opening menu failed');
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Lab menu opened');
  }

  onShowFileSelector(
    fileSelector: FileSelectorParam,
    result: FileSelectorResult
  ): boolean {
    this.cancelPendingFileSelection();
    try {
      const acceptTypes: Array<string> = fileSelector.getAcceptType();
      const mimeTypes: Array<string> = fileSelector.getMimeTypes();
      const mode: FileSelectorMode = fileSelector.getMode();
      const capture: boolean = fileSelector.isCapture();
      const multiple: boolean = mode === FileSelectorMode.FileOpenMultipleMode;
      this.state.fileParameters =
        `MIME ${this.joinOrFallback(mimeTypes, acceptTypes)}, ` +
        `${multiple ? 'multiple' : 'single'}, capture ${capture ? 'on' : 'off'}`;
      this.state.fileMultipleAllowed = multiple;
      this.state.filePickerVisible = true;
      this.fileSelectorResult = result;
      this.state.status = capture
        ? 'Capture request read, select a demo photo'
        : 'Select a demo photo';

      hilog.info(
        LOG_DOMAIN,
        LOG_TAG,
        'File selector. title=%{public}s mode=%{public}d capture=%{public}s accept=%{public}s mime=%{public}s',
        fileSelector.getTitle(),
        mode,
        capture.toString(),
        acceptTypes.join(','),
        mimeTypes.join(',')
      );

      return true;
    } catch (error) {
      this.reportError('Reading file parameters', error as Object);
      this.finishFileSelection(result, []);
      return true;
    }
  }

  selectDemoPhotos(choice: DemoPhotoChoice): void {
    const result: FileSelectorResult | undefined = this.fileSelectorResult;
    if (!result) {
      this.state.filePickerVisible = false;
      this.state.status = 'File selection is no longer active';
      return;
    }

    try {
      let selectedUris: Array<string> = [];
      switch (choice) {
        case DemoPhotoChoice.SKY:
          selectedUris = this.samplePhotoUris.length > 0
            ? [this.samplePhotoUris[0]]
            : [];
          break;
        case DemoPhotoChoice.LEAF:
          selectedUris = this.samplePhotoUris.length > 1
            ? [this.samplePhotoUris[1]]
            : [];
          break;
        case DemoPhotoChoice.BOTH:
          selectedUris = this.state.fileMultipleAllowed
            ? this.samplePhotoUris
            : this.samplePhotoUris.slice(0, 1);
          break;
        case DemoPhotoChoice.CANCEL:
          selectedUris = [];
          break;
      }

      if (!this.finishFileSelection(result, selectedUris)) {
        return;
      }
      this.state.status = selectedUris.length > 0
        ? `${selectedUris.length} demo photo(s) sent to the web form`
        : 'Photo selection cancelled';
      hilog.info(
        LOG_DOMAIN,
        LOG_TAG,
        'FileSelectorResult completed. choice=%{public}s count=%{public}d',
        choice,
        selectedUris.length
      );
    } catch (error) {
      this.reportError('Sending photo to web form', error as Object);
      this.finishFileSelection(result, []);
    } finally {
      this.fileSelectorResult = undefined;
      this.state.filePickerVisible = false;
    }
  }

  attachKeyboard(
    controller: WebKeyboardController,
    attributes: Record<string, string>
  ): void {
    this.keyboardController = controller;
    this.state.status = 'Wearable keyboard ready';
    hilog.info(
      LOG_DOMAIN,
      LOG_TAG,
      'Custom keyboard attached. attributes=%{public}s',
      JSON.stringify(attributes)
    );
  }

  insertKeyboardText(text: string): void {
    try {
      if (!this.keyboardController) {
        this.state.status = 'Keyboard controller is not attached';
        return;
      }
      this.keyboardController.insertText(text);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Keyboard text inserted. length=%{public}d', text.length);
    } catch (error) {
      this.reportError('Inserting keyboard text', error as Object);
    }
  }

  deleteKeyboardText(): void {
    try {
      if (!this.keyboardController) {
        this.state.status = 'Keyboard controller is not attached';
        return;
      }
      this.keyboardController.deleteForward(1);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Keyboard deleted one character');
    } catch (error) {
      this.reportError('Deleting keyboard character', error as Object);
    }
  }

  finishKeyboard(enterKeyType: number): void {
    try {
      if (!this.keyboardController) {
        this.state.status = 'Keyboard controller is not attached';
        return;
      }
      this.keyboardController.sendFunctionKey(enterKeyType);
      this.controller.runJavaScript(
        'if (document.activeElement) { document.activeElement.blur(); }'
      ).catch((error: BusinessError) => {
        hilog.warn(
          LOG_DOMAIN,
          LOG_TAG,
          'Web input blur failed. code=%{public}d message=%{public}s',
          error.code,
          error.message
        );
      });
      this.keyboardController.close();
      this.keyboardController = undefined;
      this.state.status = 'Comment entry complete';
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Keyboard closed');
    } catch (error) {
      this.reportError('Closing keyboard', error as Object);
    }
  }

  onContextMenuShow(
    param: WebContextMenuParam,
    result: WebContextMenuResult
  ): boolean {
    this.closePreviousContextMenu();
    this.contextMenuResult = result;
    this.selectedText = param.getSelectionText();
    this.linkUrl = param.getLinkUrl();
    this.sourceUrl = param.getSourceUrl();
    this.contextHasImage = param.existsImageContents();

    const target: string =
      this.selectedText || this.linkUrl || this.sourceUrl || 'Web item';
    const kind: string = this.contextHasImage
      ? 'image'
      : param.isEditable() ? 'editable field' : 'text/link';

    this.state.contextTitle = this.shorten(target, 34);
    this.state.contextDetails =
      `${kind}, x:${param.x()} y:${param.y()}`;
    this.state.contextMenuVisible = true;
    this.ignoreNextContextMenuHide = true;
    this.state.status = 'Custom context menu opened';

    hilog.info(
      LOG_DOMAIN,
      LOG_TAG,
      'Context menu. selected=%{public}s link=%{public}s source=%{public}s image=%{public}s editable=%{public}s',
      this.selectedText,
      this.linkUrl,
      this.sourceUrl,
      this.contextHasImage.toString(),
      param.isEditable().toString()
    );
    return true;
  }

  onContextMenuHidden(): void {
    if (
      this.ignoreNextContextMenuHide &&
      this.contextMenuResult &&
      this.state.contextMenuVisible
    ) {
      this.ignoreNextContextMenuHide = false;
      hilog.info(
        LOG_DOMAIN,
        LOG_TAG,
        'Initial ArkWeb menu hide ignored; native action sheet remains active'
      );
      return;
    }
    const result: WebContextMenuResult | undefined = this.contextMenuResult;
    this.ignoreNextContextMenuHide = false;
    this.state.contextMenuVisible = false;
    this.contextMenuResult = undefined;
    if (result) {
      try {
        result.closeContextMenu();
      } catch (error) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Hidden context menu cleanup failed');
      }
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Context menu hidden by ArkWeb');
  }

  performContextAction(action: ContextAction): void {
    const result: WebContextMenuResult | undefined = this.contextMenuResult;
    if (!result) {
      this.state.contextMenuVisible = false;
      this.state.status = 'Context menu is no longer active';
      return;
    }

    try {
      switch (action) {
        case ContextAction.COPY:
          if (this.contextHasImage) {
            result.copyImage();
            this.state.status = 'Image copied';
          } else {
            result.copy();
            this.state.status = 'Selected text copied';
          }
          break;
        case ContextAction.SELECT_ALL:
          result.selectAll();
          this.state.status = 'Web content selected';
          break;
        case ContextAction.LOOK_UP:
          this.lookUpSelection();
          break;
        case ContextAction.CLOSE:
          this.state.status = 'Context menu closed';
          break;
      }
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Context action completed. action=%{public}s', action);
    } catch (error) {
      this.reportError('Context menu operation', error as Object);
    } finally {
      this.ignoreNextContextMenuHide = false;
      this.contextMenuResult = undefined;
      this.state.contextMenuVisible = false;
      try {
        result.closeContextMenu();
      } catch (error) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'Context menu final close failed');
      }
    }
  }

  onSearchResult(matchCount: number, done: boolean): void {
    if (done) {
      this.state.status = `Find on page, ${matchCount} match(es)`;
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Search completed. matches=%{public}d', matchCount);
    }
  }

  onDataResubmitted(handler: DataResubmissionHandler): void {
    if (this.resubmissionHandler) {
      this.resubmissionHandler.cancel();
    }
    this.resubmissionHandler = handler;
    this.state.resubmissionVisible = true;
    this.state.status = 'Resend form data?';
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Data resubmission requested');
  }

  resolveResubmission(resend: boolean): void {
    const handler: DataResubmissionHandler | undefined = this.resubmissionHandler;
    if (!handler) {
      this.state.resubmissionVisible = false;
      this.state.status = 'No pending form operation';
      return;
    }

    try {
      if (resend) {
        handler.resend();
        this.state.status = 'Resending form data';
      } else {
        handler.cancel();
        this.state.status = 'Resubmission cancelled';
      }
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Resubmission resolved. resend=%{public}s', resend.toString());
      if (this.state.guidedMode &&
        this.state.currentSection === LabSection.COOKIE_AND_POST) {
        this.completeGuidedDemo();
      }
    } catch (error) {
      this.reportError('Form resubmission', error as Object);
    } finally {
      this.resubmissionHandler = undefined;
      this.state.resubmissionVisible = false;
    }
  }

  refresh(): void {
    try {
      this.controller.refresh();
      this.state.status = 'Refreshing page';
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Refresh requested');
    } catch (error) {
      this.reportError('Refreshing page', error as Object);
    }
  }

  dispose(): void {
    const keyboard: WebKeyboardController | undefined = this.keyboardController;
    const fileResult: FileSelectorResult | undefined = this.fileSelectorResult;
    const contextResult: WebContextMenuResult | undefined = this.contextMenuResult;
    const resubmission: DataResubmissionHandler | undefined = this.resubmissionHandler;

    this.keyboardController = undefined;
    this.fileSelectorResult = undefined;
    this.contextMenuResult = undefined;
    this.resubmissionHandler = undefined;
    this.ignoreNextContextMenuHide = false;

    try {
      keyboard?.close();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Keyboard cleanup failed');
    }
    try {
      fileResult?.handleFileList([]);
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'File selector cleanup failed');
    }
    try {
      contextResult?.closeContextMenu();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Context menu cleanup failed');
    }
    try {
      resubmission?.cancel();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Resubmission cleanup failed');
    }
    try {
      this.controller.clearMatches();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Search cleanup failed');
    }
  }

  private prepareCookie(): void {
    try {
      webview.WebCookieManager.configCookieSync(
        DEMO_ORIGIN,
        `${COOKIE_NAME}=wearable-user; Path=/; Max-Age=3600`
      );
      const cookieHeader: string =
        webview.WebCookieManager.fetchCookieSync(`${DEMO_ORIGIN}/index.html`);
      this.state.cookieValue =
        this.getCookieValue(cookieHeader, COOKIE_NAME) || 'not found';
      hilog.info(
        LOG_DOMAIN,
        LOG_TAG,
        'Cookie prepared. name=%{public}s value=%{public}s',
        COOKIE_NAME,
        this.state.cookieValue
      );
    } catch (error) {
      this.state.cookieValue = 'error';
      this.reportError('Preparing cookie', error as Object);
    }
  }

  private loadLocalForm(): boolean {
    if (!this.localFormHtml) {
      this.state.status = 'Local form content is unavailable';
      return false;
    }
    this.pageReady = false;
    this.postResultVisible = false;
    try {
      this.controller.loadData(
        this.localFormHtml,
        'text/html',
        'UTF-8',
        `${DEMO_ORIGIN}/index.html`,
        `${DEMO_ORIGIN}/index.html`
      );
      return true;
    } catch (error) {
      this.reportError('Loading local form', error as Object);
      return false;
    }
  }

  private scrollToSection(section: LabSection): void {
    if (!this.pageReady || section === LabSection.HOME) {
      return;
    }
    const elementId: string = this.getSectionElementId(section);
    const script: string =
      `(() => { const target = document.getElementById('${elementId}');` +
      `document.querySelectorAll('.lab-active').forEach((item) => ` +
      `item.classList.remove('lab-active'));` +
      `if (target) { target.classList.add('lab-active');` +
      `target.scrollIntoView({ behavior: 'smooth', block: 'center' }); } })();`;
    this.controller.runJavaScript(script).catch((error: BusinessError) => {
      hilog.warn(
        LOG_DOMAIN,
        LOG_TAG,
        'Section scroll failed. code=%{public}d message=%{public}s',
        error.code,
        error.message
      );
    });
  }

  private getSectionElementId(section: LabSection): string {
    switch (section) {
      case LabSection.FILE:
        return 'file-demo';
      case LabSection.KEYBOARD:
        return 'keyboard-demo';
      case LabSection.CONTEXT_MENU:
        return 'context-demo';
      case LabSection.COOKIE_AND_POST:
        return 'cookie-demo';
      default:
        return 'file-demo';
    }
  }

  private getSectionInstruction(section: LabSection): string {
    switch (section) {
      case LabSection.FILE:
        return 'Select one or more demo photos';
      case LabSection.KEYBOARD:
        return 'Tap comment to open the keyboard';
      case LabSection.CONTEXT_MENU:
        return 'Long-press the sample image or link';
      case LabSection.COOKIE_AND_POST:
        return 'Submit, refresh, resolve resend';
      default:
        return 'Choose a feature or start the guided demo';
    }
  }

  private completeGuidedDemo(): void {
    this.state.currentSection = LabSection.HOME;
    this.state.menuVisible = true;
    this.state.guidedMode = false;
    this.state.guidedStep = 0;
    this.state.status = 'Guided demo complete - all four features explored';
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Guided demo completed');
  }

  private prepareSamplePhotos(context: common.Context): void {
    const rawNames: Array<string> = [
      'sample_sky.svg',
      'sample_leaf.svg'
    ];
    const fileNames: Array<string> = [
      'wearable_sky.svg',
      'wearable_leaf.svg'
    ];
    const uris: Array<string> = [];

    try {
      for (let index: number = 0; index < rawNames.length; index++) {
        const bytes: Uint8Array =
          context.resourceManager.getRawFileContentSync(rawNames[index]);
        const path: string = `${context.cacheDir}/${fileNames[index]}`;
        const file: fileIo.File = fileIo.openSync(
          path,
          fileIo.OpenMode.READ_WRITE |
          fileIo.OpenMode.CREATE |
          fileIo.OpenMode.TRUNC
        );
        try {
          fileIo.writeSync(file.fd, bytes.buffer);
        } finally {
          fileIo.closeSync(file);
        }
        uris.push(fileUri.getUriFromPath(path));
      }
    } catch (error) {
      this.samplePhotoUris = [];
      this.reportError('Preparing demo photos', error as Object);
      return;
    }

    this.samplePhotoUris = uris;
    hilog.info(
      LOG_DOMAIN,
      LOG_TAG,
      'Wearable sample photos prepared. count=%{public}d',
      uris.length
    );
  }

  private getCookieValue(cookieHeader: string, name: string): string | undefined {
    const cookies: Array<string> = cookieHeader.split(';');
    for (let index: number = 0; index < cookies.length; index++) {
      const pair: string = cookies[index].trim();
      const separator: number = pair.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      if (pair.substring(0, separator) === name) {
        return pair.substring(separator + 1);
      }
    }
    return undefined;
  }

  private cancelPendingFileSelection(): void {
    const result: FileSelectorResult | undefined = this.fileSelectorResult;
    this.fileSelectorResult = undefined;
    if (!result) {
      return;
    }
    if (!this.finishFileSelection(result, [])) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Previous file selector cancellation failed');
    }
  }

  private finishFileSelection(
    result: FileSelectorResult,
    uris: Array<string>
  ): boolean {
    try {
      result.handleFileList(uris);
      return true;
    } catch (error) {
      this.reportError('Completing file selection', error as Object);
      return false;
    }
  }

  private lookUpSelection(): void {
    const query: string =
      (this.selectedText || this.linkUrl || this.sourceUrl).trim();
    if (!query) {
      this.state.status = 'No text to find';
      return;
    }
    try {
      this.controller.searchAllAsync(query);
      this.state.status = `Find on page, ${this.shorten(query, 22)}`;
    } catch (error) {
      this.reportError('Finding on page', error as Object);
    }
  }

  private closePreviousContextMenu(): void {
    const result: WebContextMenuResult | undefined = this.contextMenuResult;
    if (!result) {
      return;
    }
    this.contextMenuResult = undefined;
    this.ignoreNextContextMenuHide = false;
    this.state.contextMenuVisible = false;
    try {
      result.closeContextMenu();
    } catch (error) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Previous context menu close failed');
    }
  }

  private joinOrFallback(
    primary: Array<string>,
    fallback: Array<string>
  ): string {
    const values: Array<string> = primary.length > 0 ? primary : fallback;
    return values.length > 0 ? values.join(',') : '*/*';
  }

  private shorten(value: string, maximum: number): string {
    return value.length > maximum
      ? `${value.substring(0, maximum - 1)}…`
      : value;
  }

  private reportError(operation: string, error: Object): void {
    const businessError: BusinessError = error as BusinessError;
    const code: number = businessError.code || -1;
    const message: string =
      businessError.message || JSON.stringify(error) || 'Unknown error';
    this.state.status = `${operation} error ${code}`;
    hilog.error(
      LOG_DOMAIN,
      LOG_TAG,
      '%{public}s failed. code=%{public}d message=%{public}s',
      operation,
      code,
      message
    );
  }
}
