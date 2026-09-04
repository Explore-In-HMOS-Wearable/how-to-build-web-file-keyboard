export enum ContextAction {
  COPY = 'copy',
  SELECT_ALL = 'selectAll',
  LOOK_UP = 'lookUp',
  CLOSE = 'close'
}

export enum DemoPhotoChoice {
  SKY = 'sky',
  LEAF = 'leaf',
  BOTH = 'both',
  CANCEL = 'cancel'
}

export enum LabSection {
  HOME = 'home',
  FILE = 'file',
  KEYBOARD = 'keyboard',
  CONTEXT_MENU = 'contextMenu',
  COOKIE_AND_POST = 'cookieAndPost'
}

@Observed
export class WebInteractionState {
  status: string = 'Preparing demo';
  currentSection: LabSection = LabSection.HOME;
  menuVisible: boolean = true;
  guidedMode: boolean = false;
  guidedStep: number = 0;
  fileParameters: string = 'Waiting for file selector';
  cookieValue: string = 'Not ready';
  filePickerVisible: boolean = false;
  fileMultipleAllowed: boolean = false;
  contextMenuVisible: boolean = false;
  contextTitle: string = 'Web menu';
  contextDetails: string = 'Long-press text, a link, or an image';
  resubmissionVisible: boolean = false;
}
