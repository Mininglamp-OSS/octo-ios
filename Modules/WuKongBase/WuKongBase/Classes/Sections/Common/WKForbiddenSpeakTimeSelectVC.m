//
//  WKForbiddenSpeakTimeSelectVC.m
//  WuKongBase
//
//  Created by tt on 2022/3/25.
//

#import "WKForbiddenSpeakTimeSelectVC.h"
#import <ActionSheetPicker_3_0/ActionSheetCustomPickerDelegate.h>
#import <ActionSheetPicker_3_0/ActionSheetCustomPicker.h>

@interface WKForbiddenSpeakTimeSelectVC ()<WKForbiddenSpeakTimeSelectVMDelegate,ActionSheetCustomPickerDelegate>

@property(nonatomic,strong) NSArray<NSString*> *days;
@property(nonatomic,strong) NSArray<NSString*> *hours;
@property(nonatomic,strong) NSArray<NSString*> *minutes;

@property(nonatomic,copy) NSString *selectedDay;
@property(nonatomic,copy) NSString *selectedHour;
@property(nonatomic,copy) NSString *selectedMinute;

@end

@implementation WKForbiddenSpeakTimeSelectVC

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.viewModel = [[WKForbiddenSpeakTimeSelectVM alloc] init];
        self.viewModel.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LLang(@"禁言时长");
    
    self.viewModel.channel = self.channel;
    self.viewModel.uid = self.uid;
    
    self.selectedDay = @"2";
    self.selectedHour = @"0";
    self.selectedMinute = @"0";
}

- (NSArray *)days {
    if(!_days) {
        NSMutableArray *days = [NSMutableArray array];
        for (NSInteger i=0; i<=29; i++) {
            [days addObject:[NSString stringWithFormat:@"%ld",(long)i]];
        }
        _days = days;
    }
    return _days;
}

-(NSArray*) hours {
    if(!_hours) {
        NSMutableArray *hours = [NSMutableArray array];
        for (NSInteger i=0; i<=23; i++) {
            [hours addObject:[NSString stringWithFormat:@"%ld",(long)i]];
        }
        _hours = hours;
    }
    return _hours;
}

- (NSArray *)minutes {
    if(!_minutes) {
        NSMutableArray *minutes = [NSMutableArray array];
        for (NSInteger i=0; i<=59; i++) {
            [minutes addObject:[NSString stringWithFormat:@"%ld",(long)i]];
        }
        _minutes = minutes;
    }
    return _minutes;
}


-(void) forbiddenSpeakTimeSelectVMDidCustomTime:(WKForbiddenSpeakTimeSelectVM*)vm {
    
   UITableViewCell *cell =  [[self.tableView visibleCells] lastObject];
    

   
    [ActionSheetCustomPicker showPickerWithTitle:@"" delegate:self showCancelButton:true origin:cell initialSelections:@[self.selectedDay,self.selectedHour,self.selectedMinute]];
}

#pragma mark -- ActionSheetCustomPickerDelegate

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 3;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    // Returns
    switch (component) {
        case 0: return [self.days count];
        case 1: return [self.hours count];
        case 2: return [self.minutes count];
        default:break;
    }
    return 0;
}
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    switch (component) {
        case 0: return [NSString stringWithFormat:@"%@天",self.days[(NSUInteger) row]];
        case 1: return [NSString stringWithFormat:@"%@小时",self.hours[(NSUInteger) row]];
        case 2: return [NSString stringWithFormat:@"%@分钟",self.minutes[(NSUInteger) row]];
        default:break;
    }
    return nil;
}

- (void)actionSheetPickerDidSucceed:(AbstractActionSheetPicker *)actionSheetPicker origin:(id)origin {
    self.viewModel.selectSeconds = 0;
    self.viewModel.selectSeconds += self.selectedDay.intValue * 60 * 60 * 24;
    self.viewModel.selectSeconds += self.selectedHour.intValue * 60 * 60;
    self.viewModel.selectSeconds += self.selectedMinute.intValue * 60;
    [self reloadData];
}

- (void)actionSheetPickerDidCancel:(AbstractActionSheetPicker *)actionSheetPicker origin:(id)origin {
    
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    switch (component) {
        case 0: {
            self.selectedDay = [self.days objectAtIndex:row];
            break;
        }
        case 1: {
           self.selectedHour = [self.hours objectAtIndex:row];
            break;
        }
        case 2: {
            self.selectedMinute = [self.minutes objectAtIndex:row];
            break;
           
        }
        default:break;
    }
}

@end
