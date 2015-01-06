//
//  MainScene.m
//  PROJECTNAME
//
//  Created by VadimuZ on 13/09/14.
//

#import "MainScene.h"
#import "VKSdk.h"
#import "SocialRequest.h"

SocialRequest *VK; // Общаемся с API VK

CGRect screenBounds; // Инфа по экрану
CGFloat screenScale;
CGSize screenSize;
NSInteger screenCoff;

CCNode *box; // Контейнер для букв
CCSprite *cursorImg; // Мигающий курсор
NSTimer *timerCursorBlink; // Таймер для мигающего курсора
UIAlertView *alert; // Алерт для разрыва соединения

int paddingLeft = 70; // Отступ бегущей строки
int paddingTop = 400; // Отступ бегущей строки

CCTextField *field;
CCLabelTTF *previewText; // Текст перед запуском

UIView *view; // Это для keyboard
UITextField *textField; // Поле ввода для keyboard

NSString *gameText; // Текст в игре
NSMutableArray *gameArr; // Массив всех созданных букв на слое box
NSInteger gamePosition = 0; // Текущая позиция в строке

// Шаблон для поста на стену
NSString *wallPostTemplate = @"Hey! I type %.2f letters per second. And how about you?";
NSString *wallPostText;
BOOL wallPostWait = NO; // Флаг для лочки кнопки (защита от флуда)

NSInteger gameState = 0; // Состояние игры [0 меню][1 интро][2 игра][3 результат]
NSInteger gameTotal = 0; // Всего букв в строке
NSInteger gameSuccess = 0; // Удачно введенные
NSInteger gameFailed = 0; // Введенные с ошибкой
NSString *gameLastFail = @"";
CCLabelTTF *gameLastLetter;

NSDate *timeNow; // Отсечка времени игры
NSMutableArray *grab; // Хранилиже для объектов

CCSprite *startBtn; // Кнопка старта
CCSprite *postBtn; // Кнопка поста

@implementation MainScene

-(id) init {
    if( (self=[super init]) ) {
        if(view == nil) {
            // Добавляем view на экран
            view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 320, 568)];
            view.backgroundColor  = [UIColor redColor];

            // Добавляем текстовое поля для ввода
            textField = [[UITextField alloc] initWithFrame:CGRectMake(10, 140, 300, 30)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.font = [UIFont systemFontOfSize:15];
            textField.placeholder = @"";
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
            textField.keyboardType = UIKeyboardTypeDefault;
            textField.returnKeyType = UIReturnKeyDone;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            textField.delegate = self;
            [view addSubview:textField];
            
            // Скрываем view
            // textField остается доступным, для вывода keyboard
            view.hidden = true;
            
            [[[CCDirector sharedDirector] view] addSubview:view];
        }
    }
    return self;
}

-(void) onEnter
{
    [super onEnter];

    screenBounds = [[UIScreen mainScreen] bounds];
    screenScale = [[UIScreen mainScreen] scale];
    screenSize = CGSizeMake(screenBounds.size.width * screenScale, screenBounds.size.height * screenScale);
    
    // Коэффициент множитель для разных разрешений
    // Нужен для правильного поцизионирования элементов на сцене
    if(screenSize.height == 480) {
        screenCoff = 2;
    } else {
        screenCoff = 4;
    }
    
    if(screenSize.height == 2048) {
        screenCoff = 8;
    }
    
    paddingTop = screenSize.height / (screenCoff/2) - 150;
    
    self.userInteractionEnabled = TRUE;
    self.multipleTouchEnabled = TRUE;

    gameState = 0;
    
    VK = [[SocialRequest alloc] init];
    [VK viewDidLoad];
    [VK outAuthorize];
    
    [self showStartBtn];
}

-(void) gameStart {
    
    [self clearStage];
    
    if(gameText == nil) {
        return;
    }
    NSLog(@"Phrase is: %@",  gameText);
    
    gameState = 2;
    gameSuccess = 0;
    gameFailed = 0;
    wallPostWait = NO;
    textField.text = @"";
    
    [previewText removeFromParent];
    
    box = [[CCNode alloc] init]; // Создаем контейнер для строки букв
    box.anchorPoint = ccp(0, 0);
    box.position = ccp(paddingLeft, paddingTop);
    
    float counterWindth = 0;
    
    gameArr = [[NSMutableArray alloc] init]; // В эттом массиве будем хранить буквы
    gamePosition = 0;
    
    // Создаем полосу из раздельных букв
    // Для оптимизации лучше бы конечно использовать CCLabelBMFont вместо CCLabelTTF
    for (int i = 0; i <= [gameText length]-1; i++) {
        
        NSString *letter = [gameText substringWithRange:NSMakeRange(i, 1)]; // Получаем букву из строки
        
        CCLabelTTF *elementChar = [CCLabelTTF labelWithString:letter fontName:@"Courier"fontSize:40];
        elementChar.fontColor = [CCColor colorWithRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0];
        elementChar.anchorPoint = ccp(0.5F, 0.5F);
        
        // Позиционируем в нужное место
        counterWindth = counterWindth + elementChar.contentSize.width;
        elementChar.position = ccp(counterWindth, 0);
        
        [box addChild:elementChar];
        [gameArr addObject:elementChar];
    }
    
    [self Loupe]; // Выставляем эффект лупы

    // Ставим курсор на сцену
    cursorImg = [CCSprite spriteWithImageNamed:@"cursor.png"];
    cursorImg.anchorPoint = ccp(0.5, 0.5);
    cursorImg.position = ccp(paddingLeft + 10, paddingTop);
    cursorImg.scale = 0.12;
    
    // Мигание курсора
    timerCursorBlink = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(cursorBlink)userInfo:nil repeats:YES];

    [self addChild:box]; // Добавляем контейнер на сцену
    [self addChild:cursorImg]; // Курсор на сцену
    
    [textField becomeFirstResponder]; // Выдвигаем keyboard
    
    timeNow = [NSDate date]; // Делаем отсечку времени от начала игры
    
    NSLog(@"Game start");
}

- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event {

    CGPoint touchLocation = [touch locationInNode:self];
    
    if(gameState == 0 || gameState == 3) { // Ловим нажатие на кнопку Старт
        if( [startBtn hitTestWithWorldPos:touchLocation] == true && startBtn.visible == true) {
            [self startBtnTouch];
        }
    }
    
    if(gameState == 2) { // Пока идет игра, всегда выдвигаем keyboard
        [textField becomeFirstResponder];
    }
    
    if(gameState == 3) { // Ловим нажатие на кнопку поста
        if(postBtn != nil) {
            if(postBtn.scale > 0.1) {
                if( [postBtn hitTestWithWorldPos:touchLocation] == true) {
                    [self postBtnTouch];
                }
            }
        }
    }
}

// Определяем нажатую клавишу
-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // NSLog(@"Tap: %@", string);
    [self checkLetter:string position:gamePosition]; // Получаем набранную букву
    return YES;
}

// Проверяем буквы
-(void) checkLetter:(NSString *)letter position:(NSInteger)position {
    
    // Получаем ткущую букву в строке
    NSString *one = [gameText substringWithRange:NSMakeRange(position, 1)];
    
    // Ловим баг с нажатием backspace и системных клавиш
    if([letter length] == 0) return;

    CCLabelTTF *tempObject = [gameArr objectAtIndex: position];
    
    // Исправляем ошибку
    if ( [gameLastFail isEqualToString:letter] ) {
        gameSuccess += 1;
        gameFailed -= 1;
        gameLastLetter.fontColor = [CCColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
        gameLastFail = @"";
        gameLastLetter = nil;
    } else {
        // Сравниваем введенный символ с текущим
        if([one isEqualToString:letter]) {
            gameSuccess = gameSuccess + 1;
            [self moveLine]; // Двигаем линию
        } else {
        // Допускаем ошибку
            tempObject.fontColor = [CCColor colorWithRed: 2 green: 0 blue: 0 alpha: 1];
            gameFailed = gameFailed + 1;
            gameLastFail = one; // Запоминаем какая буква всетаки должна была быть
            gameLastLetter = tempObject; // Ссылка на объект букву
            [self moveLine]; // Двигаем линию
        }
    }
    
    // Определяем конец
    if(gamePosition >= [gameArr count]) {
        NSLog(@"game over");
        gameState = 3;
        //Задвигаем клавиатуру
        [textField resignFirstResponder];
        
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(gameOver) userInfo:nil repeats:NO];
    }
}

// Получаем строку ссервера
-(NSString *) getNewGame:(NSString *)url {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:url]];
    
    NSError *error = [[NSError alloc] init];
    NSHTTPURLResponse *responseCode = nil;
    
    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error];
    
    // Обработаем ошибку, если сервер не отдал
    if([responseCode statusCode] != 200){
        NSLog(@"Error getting %@, HTTP status code %i", url, [responseCode statusCode]);
        alert = [[UIAlertView alloc] initWithTitle:@"Wait" message:@"You have troubles with internet connection!" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
        return nil;
    }
    
    return [[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding];
}

// Метод убирает объекты со сцены
-(void) clearStage {
    
    if(timerCursorBlink)
    {
        [timerCursorBlink invalidate];
        timerCursorBlink = nil;
    }
    
    if(cursorImg) {
        [self removeChild:cursorImg cleanup: YES];
        cursorImg = nil;
    }
    
    if(box) {
        [self removeChild:box cleanup: YES];
        box = nil;
    }
}

// Конец игры
-(void) gameOver {
    gameState = 3;

    // Подсчет результатов
    float roundTime = floorf((-1 * [timeNow timeIntervalSinceNow]) * 100) / 100;
    float roundSpeed = floorf((roundTime / gameSuccess) * 100) / 100;
    roundSpeed = 1 / roundSpeed; // Letters per seconds
    
    // Текст для поста
    wallPostText = [NSString stringWithFormat:wallPostTemplate, roundSpeed];

    [self clearStage];
    
    // Выставляем отображение результатов
    [NSTimer scheduledTimerWithTimeInterval:6 target:self selector:@selector(showStartBtn)userInfo:nil repeats:NO];
    
    [self createAnimateText:[NSString stringWithFormat:@"%@", @"Your score"] paddingTop:15 dalay:1 ];
    
    [self createAnimateText:[NSString stringWithFormat:@"%@%d%@", @"Total ", [gameArr count], @" letters"] paddingTop:45 dalay:1.5f ];
    
    [self createAnimateText: [NSString stringWithFormat:@"%@%d%@", @"Correctly ", gameSuccess, @" letters"] paddingTop:75 dalay:2 ];
    
    [self createAnimateText:[NSString stringWithFormat:@"%@%d%@", @"Mistakes ", gameFailed, @" letters"] paddingTop:105 dalay:2.5f ];
    
    [self createAnimateText:[NSString stringWithFormat:@"%@%.2f%@", @"Your spent ", roundTime, @" seconds"] paddingTop:135 dalay:3 ];
    
    [self createAnimateText:[NSString stringWithFormat:@"%@%.2f%@", @"Your speed ", roundSpeed, @" per sec."] paddingTop:165 dalay:3.5f ];

    // Кнопка поста
    if(postBtn == nil) {
        postBtn = [CCSprite spriteWithImageNamed:@"postBtn.png"];
        postBtn.anchorPoint = ccp(0.5, 0.5);
        postBtn.position = ccp(screenSize.width / screenCoff, screenSize.height/(screenCoff/2) - 225);
        [self addChild:postBtn];
    }
    
    // Анимация кнопки
    postBtn.scale = 0;
    postBtn.visible = true;
    [postBtn stopAllActions];
    CCActionScaleTo *scaleTo = [CCActionScaleTo actionWithDuration:3 scale:(0.2f)];
    CCActionEaseElasticOut *ease = [CCActionEaseElasticOut actionWithAction:scaleTo];
    CCActionDelay *delay = [CCActionDelay actionWithDuration:4.5f];
    CCActionSequence *sequence = [CCActionSequence actions: delay, ease, scaleTo, nil];
    [postBtn runAction: sequence];
}

// Метод конструктор для анимаций
-(void) createAnimateText:(NSString*)text paddingTop:(int)paddingTop dalay:(float)getDelay {
    
    CCLabelTTF *object = [CCLabelTTF labelWithString:text fontName:@"Courier" fontSize:16];
    object.fontColor = [CCColor colorWithRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0];
    object.anchorPoint = ccp(0.5, 1);
    object.position = ccp(screenSize.width / screenCoff, screenSize.height/(screenCoff/2) - paddingTop);
    object.dimensions =  CGSizeMake(screenSize.width / (screenCoff/2) - 30, screenSize.height/(screenCoff/2));
    object.horizontalAlignment = CCVerticalTextAlignmentCenter;
    [self addChild:object];
    [self addToGrab:object]; // Помещаем в массив сборщик
    
    object.scale = 0;
    [object stopAllActions];
    CCActionScaleTo *scaleTo = [CCActionScaleTo actionWithDuration:3 scale:(1)];
    CCActionEaseElasticOut *ease = [CCActionEaseElasticOut actionWithAction:scaleTo];
    CCActionDelay *delay = [CCActionDelay actionWithDuration:getDelay];
    CCActionSequence *sequence = [CCActionSequence actions: delay, ease, scaleTo, nil];
    [object runAction: sequence];
}

// Показываем кнопку старта
-(void) showStartBtn {
    if(startBtn == nil) {
        startBtn = [CCSprite spriteWithImageNamed:@"startBtn.png"];
        startBtn.anchorPoint = ccp(0.5, 0.5);
        startBtn.position = ccp(screenSize.width / screenCoff, screenSize.height / (screenCoff*2));
        [self addChild:startBtn];
    }
    startBtn.scale = 0;
    startBtn.visible = true;
    [startBtn stopAllActions];
    CCActionScaleTo *scaleTo = [CCActionScaleTo actionWithDuration:3 scale:(0.3f)];
    CCActionEaseElasticOut *ease = [CCActionEaseElasticOut actionWithAction:scaleTo];
    CCActionSequence *sequence = [CCActionSequence actions: ease, scaleTo, nil];
    [startBtn runAction: sequence];
}

// Тапнули по кнопке старта
-(void) startBtnTouch {

    //[VK logout:self];
    //return;
    
    [self clearGrab]; // Чистим сборщик

    if(postBtn) {
        [self removeChild:postBtn cleanup: YES];
        postBtn = nil;
    }
    
    startBtn.visible = false;
    
    // Получаем строку с сервера
    gameText = [self getNewGame:@"http://neobanner.com/cms/phrase.php"];
    if(gameText == nil) {
        return;
    }
    
    // Текст перед стартом
    previewText = [CCLabelTTF labelWithString:gameText fontName:@"Courier"fontSize:16];
    previewText.fontColor = [CCColor colorWithRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0];
    previewText.anchorPoint = ccp(0.5, 1);
    previewText.position = ccp(screenSize.width / screenCoff, screenSize.height/ (screenCoff/2) - 15);
    previewText.dimensions =  CGSizeMake(screenSize.width / (screenCoff/2) - 30, screenSize.height/(screenCoff/2));
    [self addChild:previewText];
    
    // Инициализируем интро
    [self gameIntro:3];
}

// Интро вызывается рекурсивно 3 раза
-(void) gameIntro:(int)pos {
    CCSprite *showCase;
    NSString *fileName = [NSString stringWithFormat:@"%@%d%@", @"p", pos, @".png"];
    showCase = [CCSprite spriteWithImageNamed:fileName];
    showCase.anchorPoint = ccp(0.5, 0.5);
    showCase.position = ccp(screenSize.width / screenCoff, screenSize.height / (screenCoff * 2));
    showCase.scale = 0;
    [self addChild:showCase];
    
    [showCase stopAllActions];
    CCActionScaleTo *scaleTo = [CCActionScaleTo actionWithDuration:1 scale:(0.2f)];
    CCActionEaseElasticOut *ease = [CCActionEaseElasticOut actionWithAction:scaleTo];
    CCActionCallBlock *callback = [CCActionCallBlock actionWithBlock:^{
        [showCase removeFromParent];
        if(pos <= 1) {
            [self gameStart];
        } else {
            [self gameIntro:pos-1];
        }
    }];
    CCActionSequence *sequence = [CCActionSequence actions: ease, scaleTo, callback, nil];
    [showCase runAction: sequence];
}

// Нажатие на кнопку поста на стену
-(void) postBtnTouch {
    if(wallPostWait == NO) {
        // Ставим лочку на кнопку
        wallPostWait = YES;
        // Отправляем запрос
        [VK postOnWall:wallPostText fromObject:self];
    }
    //  Лочим клик по кнопке на 2 секунды, защита от флуда
    [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(postBtnLockOff) userInfo:nil repeats:NO];
}

// Снимаем лочку
-(void) postBtnLockOff {
    wallPostWait = NO;
}

// Постинг прошел успешно
-(void)wallPostComplete {
    [postBtn stopAllActions];
    CCActionScaleTo *scaleTo = [CCActionScaleTo actionWithDuration:3 scale:(0)];
    CCActionEaseIn *ease = [CCActionEaseIn actionWithAction:scaleTo];
    CCActionSequence *sequence = [CCActionSequence actions:ease, scaleTo, nil];
    [postBtn runAction: sequence];
}

// Жвигаем линию с буквами
-(void)moveLine {
    
    if(gamePosition >= gameArr.count) return;
    
    CCLabelTTF *tempObject;
    
    float goToX = 0;
    
    gamePosition = gamePosition + 1;
    
    // Вычисляем координату
    // Можно обойтись и без цикла, храня посленюю координату и вычисляя от нее
    // Лучше перестраховаться и пересчитать строку
    for (int i = 0; i < gamePosition; i++) {
        tempObject = [gameArr objectAtIndex: i];
        goToX = goToX + tempObject.contentSize.width;
    }
    
    // Уменьшаем последнюю
    if(gamePosition - 1 >= 0) {
        tempObject = [gameArr objectAtIndex: (gamePosition - 1)];
        tempObject.opacity = 0.5;
        [tempObject stopAllActions];
        CCActionScaleTo *scaleTo = [CCActionScaleTo actionWithDuration:0.3 scale:(0.5f)];
        [tempObject runAction:scaleTo];
    }
    
    [self Loupe]; // Эффект лупы
    
    // Двигаем строку
    [box stopAllActions];
    CCActionMoveTo *moveTo2 = [CCActionMoveTo actionWithDuration:0.25f position:ccp(-1 * goToX + paddingLeft, box.position.y)];
    [box runAction:moveTo2];
}

// Выставляем эффект лупы
-(void)Loupe {
    float fontCoffNow = 1;
    CCLabelTTF *tempObject;
    for (int i = gamePosition + 1; i <= [gameArr count]-1; i++) {
        tempObject = [gameArr objectAtIndex: i];
        if(fontCoffNow > 0.3) {
            fontCoffNow = fontCoffNow - 0.07;
        }
        [tempObject stopAllActions];
        CCActionScaleTo *scaleTo = [CCActionScaleTo actionWithDuration:0.3 scale:(fontCoffNow)];
        [tempObject runAction:scaleTo];
    }
}

// Делаем курсор полупрозрачным
-(void) cursorBlink {
    cursorImg.opacity = 0.25;
    // Здесь ссылка на таймер не нужна т.к. он выполняется 1н раз
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(showCursor)userInfo:nil repeats:NO];
}

// Возвращаем курсор на исходную
-(void) showCursor {
    cursorImg.opacity = 1;
}

// CallBack на Alert
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0){
        [self showStartBtn];
    }
}

// Добавляем в сборщик
-(void) addToGrab:(CCLabelTTF*)object {
    if (grab == nil) {
        grab = [[NSMutableArray alloc] init];
    }
    [grab addObject:object];
}

// Чистим сборщик
-(void) clearGrab {
    if(grab == nil) return;
    for (int i = 0; i <= [grab count]-1; i++) {
        [[grab objectAtIndex: i] removeFromParent];
    }
    grab = [[NSMutableArray alloc] init];
}

@end