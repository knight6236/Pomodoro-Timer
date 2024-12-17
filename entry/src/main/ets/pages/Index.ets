import { promptAction } from '@kit.ArkUI';
import dataPreferences from '@ohos.data.preferences';

// 添加任务分类枚举
enum TaskCategory {
  All = "全部",
  Study = '学习',
  Work = '工作',
  Life = '生活',
  Other = '其他',
}

// 添加任务优先级枚举
enum TaskPriority {
  High = '高',
  Medium = '中',
  Low = '低'
}

// 添加一个获取所有分类的方法
const getAllCategories = (): TaskCategory[] => {
  return [
    TaskCategory.All,
    TaskCategory.Study,
    TaskCategory.Work,
    TaskCategory.Life,
    TaskCategory.Other,
  ];
}

// 添加分类时间配置接口
interface CategoryTimeConfig {
  workTime: number; // 工作时间（分钟）
  breakTime: number; // 休息时间（分钟）
}

// 添加分类时间配置
const categoryTimeConfigs: Record<TaskCategory, CategoryTimeConfig> = {
  [TaskCategory.All]: { workTime: 25, breakTime: 5 },
  [TaskCategory.Study]: { workTime: 45, breakTime: 10 }, // 学习时间更长
  [TaskCategory.Work]: { workTime: 25, breakTime: 5 }, // 标准番茄时间
  [TaskCategory.Life]: { workTime: 15, breakTime: 5 }, // 生活任务时间较短
  [TaskCategory.Other]: { workTime: 20, breakTime: 5 }, // 其他任务适中
}

// 修改任务接口，添加category字段
interface Task {
  id: number;
  title: string;
  completed: boolean;
  pomodoros: number;
  todayPomodoros: number;
  lastPomodoroDate: string;
  category: TaskCategory; // 新增字段
  priority: TaskPriority; // 新增字段
}

// 添加主题颜色接口
interface ThemeColors {
  primary: string;
  secondary: string;
  background: string;
  selectedBackground: string;
  cardBg: string;
  textPrimary: string;
  textSecondary: string;
}

@Entry
@Component
struct Index {
  @State selectedCategory: TaskCategory = TaskCategory.All; // 显示当前类别
  @State addCategory: TaskCategory = TaskCategory.Work; // 新增当前类别
  @State selectedPriority: TaskPriority = TaskPriority.Medium; // 新增状态
  @State remainingTime: number = categoryTimeConfigs[this.selectedCategory].workTime * 60;
  @State isRunning: boolean = false;
  @State isWorkTime: boolean = true;
  @State tasks: Task[] = [];
  @State newTask: string = '';
  @State currentTaskId: number = -1;
  @State totalPomodoros: number = 0;
  @State todayPomodoros: number = 0;
  @State showAddTask: boolean = false;
  @State todayDate: string = new Date().toDateString();
  @State refreshFlag: number = 0;
  private timer: number = 0;
  private preferences: dataPreferences.Preferences | null = null;
  // 添加 dialogController
  dialogController: CustomDialogController = new CustomDialogController({
    builder: this.DialogBuilder,
    alignment: DialogAlignment.Center,
    offset: { dx: 0, dy: -20 },
    customStyle: true,
    autoCancel: true,
    cancel: () => {
      this.showAddTask = false;
    }
  });
  // 添加删除对话框控制器
  deleteDialogController: CustomDialogController = new CustomDialogController({
    builder: this.DeleteDialogBuilder,
    alignment: DialogAlignment.Center,
    offset: { dx: 0, dy: -20 },
    customStyle: true,
    autoCancel: true
  });
  // 当前要删除的任务ID
  @State taskToDelete: Task | null = null;

  // 定义对话框内容构建器
  @Builder
  DialogBuilder() {
    Column() {
      Text('添加任务')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      TextInput({ placeholder: '输入任务名称' })
        .width('90%')
        .height(50)
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.newTask = value;
        })

      // 添加分类选择
      Select([
        { value: TaskCategory.Work },
        { value: TaskCategory.Study },
        { value: TaskCategory.Life },
        { value: TaskCategory.Other }
      ])// .selected(0)
        .value(this.addCategory)
        .width('90%')
        .selectedOptionBgColor(this.themeColors.selectedBackground)
        .selectedOptionFontColor(this.themeColors.textPrimary)
        .margin({ top: 16 })
        .onSelect((index, value) => {
          this.addCategory = value as TaskCategory;
          this.currentTaskId = -1
        })

      // 添加优先级选择
      Select([
        { value: TaskPriority.High },
        { value: TaskPriority.Medium },
        { value: TaskPriority.Low }
      ])
        .selected(1)// 默认选中中等优先级
        .value(TaskPriority.Medium)
        .width('90%')
        .selectedOptionBgColor(this.themeColors.selectedBackground)
        .selectedOptionFontColor(this.themeColors.textPrimary)
        .margin({ top: 8 })
        .onSelect((index, value) => {
          this.selectedPriority = value as TaskPriority;
        })

      Row() {
        Button('取消')
          .width('40%')
          .height(40)
          .backgroundColor(this.themeColors.textSecondary)
          .margin({ top: 20, right: 8 })
          .onClick(() => {
            this.dialogController.close();
            this.showAddTask = false;
          })

        Button('添加')
          .width('40%')
          .height(40)
          .backgroundColor(this.themeColors.primary)
          .margin({ top: 20, left: 8 })
          .onClick(() => {
            if (this.newTask.trim()) {
              // 检查任务名称是否重复
              if (this.isTaskNameDuplicate(this.newTask.trim())) {
                promptAction.showToast({
                  message: '任务名称已存在',
                  duration: 2000,
                });
                return;
              }
              this.createTask(this.newTask);
              this.newTask = '';
              this.dialogController.close();
              this.showAddTask = false;
            }
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceAround)
    }
    .width('90%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(24)
  }

  // 定义删除确认对话框内容
  @Builder
  DeleteDialogBuilder() {
    Column() {
      Text('确认删除')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 16 })

      Text(this.taskToDelete ? `是否删除任务"${this.taskToDelete.title}"？` : '')
        .fontSize(16)
        .fontColor(this.themeColors.textSecondary)
        .margin({ bottom: 20 })
        .textAlign(TextAlign.Center)

      Row() {
        Button('取消')
          .width('40%')
          .height(40)
          .backgroundColor(this.themeColors.textSecondary)
          .margin({ top: 20, right: 8 })
          .onClick(() => {
            this.deleteDialogController.close();
            this.taskToDelete = null;
          })

        Button('删除')
          .width('40%')
          .height(40)
          .backgroundColor(this.themeColors.primary)
          .margin({ top: 20, left: 8 })
          .onClick(() => {
            if (this.taskToDelete) {
              this.deleteTask(this.taskToDelete);
            }
            this.deleteDialogController.close();
            this.taskToDelete = null;
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceAround)
    }
    .width('90%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(24)
  }

  // 添加检查任务名称是否重复的方法
  private isTaskNameDuplicate(taskName: string): boolean {
    return this.tasks.some(task => task.title.toLowerCase() === taskName.toLowerCase());
  }

  async aboutToAppear() {
    try {
      // 获取preferences实例
      const context = getContext(this);
      this.preferences = await dataPreferences.getPreferences(context, 'PomodoroData');

      // 加载保存的数据
      const tasksStr = await this.preferences.get('tasks', '[]');
      this.tasks = JSON.parse(tasksStr as string);
      this.totalPomodoros = await this.preferences.get('totalPomodoros', 0) as number;

      // 初始化今日总番茄数
      this.updateTodayTotal();
    } catch (error) {
      console.error('Failed to load data:', error);
    }
  }

  // 添加保存数据的方法
  private async saveData() {
    if (this.preferences) {
      try {
        await this.preferences.put('tasks', JSON.stringify(this.tasks));
        await this.preferences.put('totalPomodoros', this.totalPomodoros);
        await this.preferences.flush();
      } catch (error) {
        console.error('Failed to save data:', error);
      }
    }
  }

  // 修改主题颜色定义，添加类型声明
  readonly themeColors: ThemeColors = {
    primary: '#FF6B6B', // 番茄红
    secondary: '#4ECDC4', // 清新青
    background: '#F7F7F7', // 浅灰背景
    selectedBackground: '#FFE8E8', // 浅红背景
    cardBg: '#FFFFFF', // 卡片背景
    textPrimary: '#2D3436', // 主要文字
    textSecondary: '#636E72'// 次要文字
  }

  // 获取当前任务的时间配置
  private getCurrentTaskTimeConfig(): CategoryTimeConfig {
    // if (this.currentTaskId === -1) {
    //   return categoryTimeConfigs[TaskCategory.All]; // 默认使用工作配置
    // }
    const currentTask = this.tasks.find(task => task.id === this.currentTaskId);
    if (currentTask) {
      return categoryTimeConfigs[currentTask.category];
    }
    if (this.selectedCategory) {
      return categoryTimeConfigs[this.selectedCategory]
    }
    return categoryTimeConfigs[TaskCategory.Work];
  }

  @Builder
  TimerSection() {
    Column() {
      Stack() {
        // 背景圆环
        Circle()
          .width(200)
          .height(200)
          .fill(this.themeColors.cardBg)
          .stroke(this.themeColors.background)
          .strokeWidth(8)
          .opacity(0.8)

        // 进度圆环
        Progress({
          value: this.remainingTime,
          total: this.isWorkTime ?
            this.getCurrentTaskTimeConfig().workTime * 60 :
            this.getCurrentTaskTimeConfig().breakTime * 60,
          type: ProgressType.Ring
        })
          .width(210)
          .height(210)
          .color(this.themeColors.primary)
          .style({
            strokeWidth: 8
          })

        Column() {
          Text(this.formatTime(this.remainingTime))
            .fontSize(64)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.primary)

          Stack() { // 使用Stack来实现时间文本的交替动画
            Text('专注时间')
              .fontSize(20)
              .fontColor(this.themeColors.textSecondary)
              .opacity(this.isWorkTime ? 1 : 0)
              .animation({
                duration: 300,
                curve: Curve.EaseInOut
              })

            Text('休息时间')
              .fontSize(20)
              .fontColor(this.themeColors.textSecondary)
              .opacity(this.isWorkTime ? 0 : 1)
              .animation({
                duration: 300,
                curve: Curve.EaseInOut
              })
          }
          .margin({ top: 8 })
          .height(24) // 固定高度避免切换时的抖动

          Row() {
            Text(`${this.getCurrentTaskTimeConfig().workTime}分钟`)
              .fontSize(14)
              .fontColor(this.isWorkTime ? this.themeColors.primary : this.themeColors.textSecondary)
              .opacity(this.isWorkTime ? 1 : 0.6)
              .animation({
                duration: 300,
                curve: Curve.EaseInOut
              })

            Text(' / ')
              .fontSize(14)
              .fontColor(this.themeColors.textSecondary)

            Text(`${this.getCurrentTaskTimeConfig().breakTime}分钟`)
              .fontSize(14)
              .fontColor(!this.isWorkTime ? this.themeColors.primary : this.themeColors.textSecondary)
              .opacity(!this.isWorkTime ? 1 : 0.6)
              .animation({
                duration: 300,
                curve: Curve.EaseInOut
              })
          }
          .margin({ top: 10 })
        }
      }
      .margin({ top: 5, bottom: 20 })
      .animation({
        duration: 1000,
        curve: Curve.EaseInOut
      })

      Row() {
        Button(this.isRunning ? '暂停' : '开始')
          .width(140)
          .height(48)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.isRunning ? this.themeColors.secondary : this.themeColors.primary)
          .borderRadius(24)
          .onClick(() => this.toggleTimer())

        Button('重置')
          .width(140)
          .height(48)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.themeColors.textSecondary)
          .borderRadius(24)
          .margin({ left: 16 })
          .onClick(() => this.resetTimer())
      }
      .margin({ bottom: 10 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.themeColors.cardBg)
    .borderRadius(32)
    .margin({ top: 35 })
  }

  @Builder
  TaskSection() {
    Column() {
      // 添加分类筛选和新增任务按钮
      Row() {
        // 分类筛选
        Scroll() {
          Row() {
            ForEach(getAllCategories(), (category: TaskCategory) => {
              Text(category)
                .fontSize(14)
                .fontColor(this.selectedCategory === category ?
                this.themeColors.primary : this.themeColors.textSecondary)
                .backgroundColor(this.selectedCategory === category ?
                this.themeColors.selectedBackground : 'transparent')
                .padding(8)
                .borderRadius(16)
                .margin({ right: 8 })
                .onClick(() => {
                  this.selectedCategory = category;
                  this.resetTimer();
                })
            })
          }
          .width('100%')
          .padding({ left: 5, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)

        // 新增任务按钮
        Button('+')
          .width(45)
          .height(30)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.themeColors.primary)
          .borderRadius(20)
          .margin({ right: 5 })
          .onClick(() => {
            this.showAddTask = true;
            this.dialogController.open();
          })
      }
      .width('100%')
      .margin({ top: 8, bottom: 8 })

      List() {
        ForEach(this.getSortedTasks(), (task: Task) => {
          ListItem() {
            this.TaskItem(task)
          }
          .width('100%')
          .padding(8)
          .backgroundColor(this.currentTaskId === task.id ? this.themeColors.selectedBackground :
          this.themeColors.cardBg)
          .borderRadius(10)
          .opacity(task.completed ? 0.7 : 1)
          .shadow({
            radius: 8,
            color: '#00000010',
            offsetY: 2
          })
          .margin({ bottom: 8 })
          .onClick(() => this.selectTask(task))
          .swipeAction({ end: this.DeleteButton(task) })
        })
      }
      .width('100%')
      .height('30%')
      .padding({ left: 5, right: 5 })
      .scrollBar(BarState.Auto)

      Row() {
        Text(`今日完成：${this.todayPomodoros} 🍅`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.primary)

        Blank()

        Text(`总计完成：${this.totalPomodoros} 🍅`)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textSecondary)
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })
      .backgroundColor(this.themeColors.cardBg)
      .borderRadius(16)
      .margin({ top: 16 })
    }
  }

  // 添加删除按钮构建器
  @Builder
  DeleteButton(task: Task) {
    Button() {
      Text('删除')
        .fontSize(16)
        .fontColor(Color.White)
    }
    .width(80)
    .height('100%')
    .backgroundColor(Color.Red)
    .onClick(() => {
      this.showDeleteConfirm(task);
    })
  }

  // 修改显示删除确认方法
  private showDeleteConfirm(task: Task) {
    this.taskToDelete = task;
    this.deleteDialogController.open();
  }

  // 添加删除任务方法
  private async deleteTask(delTask: Task) {
    // 如果删除的是当前选中的任务，清除选中状态
    if (delTask.id === this.currentTaskId) {
      this.currentTaskId = -1;
    }

    // 创建新的任务数组，排除要删除的任务
    const newTasks: Task[] = [];
    for (const task of this.tasks) {
      if (task.id !== delTask.id) {
        newTasks.push(task);
      }
    }

    // 更新任务列表
    this.tasks = newTasks;

    // 更新今日总番茄数
    this.updateTodayTotal();

    // 保存更改
    await this.saveData();

    // 显示删除成功提示
    promptAction.showToast({
      message: '任务 ' + delTask.title + ' 已删除',
      duration: 2000,
    });
  }

  build() {
    Column() {
      this.TimerSection()
      this.TaskSection()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .padding(16)
  }

  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  private toggleTimer() {
    if (this.isRunning) {
      clearInterval(this.timer);
    } else {
      this.timer = setInterval(async () => {
        if (this.remainingTime > 0) {
          this.remainingTime--;
        } else {
          await this.completePomodoro();
        }
      }, 1000);
    }
    this.isRunning = !this.isRunning;
  }

  private resetTimer() {
    clearInterval(this.timer);
    this.isRunning = false;
    const timeConfig = this.getCurrentTaskTimeConfig();
    this.remainingTime = this.isWorkTime ?
      timeConfig.workTime * 60 : timeConfig.breakTime * 60;
  }

  private async completePomodoro() {
    if (this.isWorkTime) {
      this.totalPomodoros++;

      if (this.currentTaskId !== -1) {
        const taskIndex = this.tasks.findIndex(t => t.id === this.currentTaskId);
        if (taskIndex !== -1) {
          // 创建新的任务数组并更新任务
          const newTasks: Task[] = [];
          for (let i = 0; i < this.tasks.length; i++) {
            if (i === taskIndex) {
              const today = new Date().toDateString();
              newTasks.push({
                id: this.tasks[i].id,
                title: this.tasks[i].title,
                completed: this.tasks[i].completed,
                pomodoros: this.tasks[i].pomodoros + 1,
                todayPomodoros: this.tasks[i].lastPomodoroDate === today ?
                  this.tasks[i].todayPomodoros + 1 : 1,
                lastPomodoroDate: today,
                category: this.tasks[i].category,
                priority: this.tasks[i].priority
              });
            } else {
              newTasks.push(this.tasks[i]);
            }
          }

          // 更新任务数组
          this.tasks = newTasks;

          // 立即更新今日总番茄数
          this.updateTodayTotal();
        }
      }

      await this.saveData();

      promptAction.showToast({
        message: '太棒了！完成了一个🍅！',
        duration: 2000,
      });
    }
    this.switchMode();
  }

  // 更新今日总番茄数
  private updateTodayTotal() {
    const today = new Date().toDateString();
    let total = 0;
    for (const task of this.tasks) {
      if (task.lastPomodoroDate === today) {
        total += task.todayPomodoros;
      }
    }
    this.todayPomodoros = total;
  }

  private switchMode() {
    this.isWorkTime = !this.isWorkTime;
    const timeConfig = this.getCurrentTaskTimeConfig();
    this.remainingTime = this.isWorkTime ?
      timeConfig.workTime * 60 : timeConfig.breakTime * 60;
    this.resetTimer();
  }

  private selectTask(task: Task) {
    if (task.completed) {
      promptAction.showToast({
        message: '任务已完成',
        duration: 2000,
      })
      return
    }
    if (this.currentTaskId === task.id) {
      this.currentTaskId = -1
    } else {
      this.currentTaskId = task.id;
    }
    // 选择新任务时重置计时器
    this.resetTimer();
  }

  private async createTask(title: string) {
    // 添加输入验证
    if (!title || title.trim().length === 0) {
      promptAction.showToast({
        message: '任务名称不能为空',
        duration: 2000,
      });
      return;
    }
    if (title.length > 20) {
      promptAction.showToast({
        message: '任务名称不能超过20个字符',
        duration: 2000,
      });
      return;
    }

    const newTask: Task = {
      id: Date.now(),
      title: title,
      completed: false,
      pomodoros: 0,
      todayPomodoros: 0,
      lastPomodoroDate: new Date().toDateString(),
      category: this.addCategory,
      priority: this.selectedPriority || TaskPriority.Medium
    };

    // 创建新数组并添加任务
    const newTasks: Task[] = [];
    for (const task of this.tasks) {
      newTasks.push(task);
    }
    newTasks.push(newTask);

    this.tasks = newTasks;
    await this.saveData();
  }

  aboutToDisappear() {
    clearInterval(this.timer);
    if (this.preferences) {
      this.preferences.flush();
    }
  }

  // 添加切换任务完成状态的方法
  private async toggleTaskComplete(taskId: number, completed: boolean) {
    const newTasks: Task[] = [];
    for (const task of this.tasks) {
      if (task.id === taskId) {
        newTasks.push({
          id: task.id,
          title: task.title,
          completed: completed,
          pomodoros: task.pomodoros,
          todayPomodoros: task.todayPomodoros,
          lastPomodoroDate: task.lastPomodoroDate,
          category: task.category,
          priority: task.priority
        });
        this.currentTaskId = -1
      } else {
        newTasks.push(task);
      }
    }
    this.tasks = newTasks;
    await this.saveData();
  }

  // 添加任务筛选方法
  private getFilteredTasks(): Task[] {
    if (this.selectedCategory === TaskCategory.All) {
      return this.tasks;
    }
    const filteredTasks: Task[] = [];
    for (const task of this.tasks) {
      if (task.category === this.selectedCategory) {
        filteredTasks.push(task);
      }
    }
    return filteredTasks;
  }

  // 获取优先级顺序值
  private getPriorityValue(priority: TaskPriority): number {
    switch (priority) {
      case TaskPriority.High:
        return 0;
      case TaskPriority.Medium:
        return 1;
      case TaskPriority.Low:
        return 2;
      default:
        return 1;
    }
  }

  // 修改任务列表显示，优化布局并排序任务
  private getSortedTasks(): Task[] {
    const filteredTasks = this.getFilteredTasks();
    return filteredTasks.sort((a, b) => {
      // 已完成的任务排在最后
      if (a.completed !== b.completed) {
        return a.completed ? 1 : -1;
      }
      // 未完成的任务按优先级排序
      if (!a.completed) {
        return this.getPriorityValue(a.priority) - this.getPriorityValue(b.priority);
      }
      return 0;
    });
  }

  // 获取优先级对应的颜色
  private getPriorityColor(priority: TaskPriority): string {
    switch (priority) {
      case TaskPriority.High:
        return '#FF4949';
      case TaskPriority.Medium:
        return '#FFA940';
      case TaskPriority.Low:
        return '#52C41A';
      default:
        return '#FFA940';
    }
  }

  // 获取优先级对应的背景色
  private getPriorityBgColor(priority: TaskPriority): string {
    switch (priority) {
      case TaskPriority.High:
        return '#FFE8E8';
      case TaskPriority.Medium:
        return '#FFF7E6';
      case TaskPriority.Low:
        return '#F6FFED';
      default:
        return '#FFF7E6';
    }
  }

  // 修改任务项显示
  @Builder
  TaskItem(task: Task) {
    Row() {
      Toggle({ type: ToggleType.Checkbox, isOn: task.completed })
        .onChange((isOn) => {
          this.toggleTaskComplete(task.id, isOn);
        })
        .margin({ right: 8 })

      Column() {
        Row() {
          Column() { // 左侧内容
            Row() { // 第一排
              Text(task.priority)
                .fontSize(16)
                .fontColor(this.getPriorityColor(task.priority))
                .backgroundColor(this.getPriorityBgColor(task.priority))
                .padding({
                  left: 6,
                  right: 16,
                  top: 2,
                  bottom: 2
                })
                .borderRadius(10)
                .margin({ right: 8 })

              Text(task.category)
                .fontSize(16)
                .fontColor(this.themeColors.primary)
                .backgroundColor(this.themeColors.selectedBackground)
                .padding({
                  left: 8,
                  right: 8,
                  top: 2,
                  bottom: 2
                })
                .borderRadius(12)
                .margin({ right: 12 })
                .visibility(this.selectedCategory === TaskCategory.All ? Visibility.Visible : Visibility.None)

              Text(task.title)
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textPrimary)
                .decoration({
                  type: task.completed ? TextDecorationType.LineThrough : TextDecorationType.None,
                  color: this.themeColors.textSecondary
                })
            }

            Row() { // 第二排
              Text(`今日：${task.todayPomodoros} 🍅`)
                .fontSize(14)
                .fontColor(this.themeColors.textSecondary)
                .margin({ right: 12 })

              Text(`总计：${task.pomodoros} 🍅`)
                .fontSize(14)
                .fontColor(this.themeColors.textSecondary)
            }
            .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.currentTaskId === task.id) {
            Text('进行中')
              .fontColor(this.themeColors.primary)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 8 })
              .transition({
                type: TransitionType.All,
                opacity: 1,
                scale: { x: 1, y: 1 }
              })
              .animation({
                duration: 1000,
                tempo: 3.0,
                delay: 0,
                curve: Curve.Linear,
                playMode: PlayMode.Alternate,
                iterations: -1
              })
              .scale({ x: 1.1, y: 1.1 })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .layoutWeight(1)
    }
  }
}