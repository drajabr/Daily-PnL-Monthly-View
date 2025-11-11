//+------------------------------------------------------------------+
//|                              smaGUY_Daily_PnL_Calendar_View.mq5  |
//|                               Daily P&L Calendar View Indicator  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025 SmaGUY"
#property version   "2.01"
#property description "Daily PnL on a monthly calendar view - Fixed Weekend Logic"
#property indicator_chart_window
#property indicator_plots 0

//--- Enums
enum ENUM_CALENDAR_POSITION
  {
   POS_TOP_LEFT = 0,
   POS_TOP_RIGHT = 1,
   POS_BOTTOM_LEFT = 2,
   POS_BOTTOM_RIGHT = 3
  };

enum ENUM_MONTH_SELECTION
  {
   MONTH_CURRENT = 0,
   MONTH_JANUARY = 1, MONTH_FEBRUARY = 2, MONTH_MARCH = 3,
   MONTH_APRIL = 4, MONTH_MAY = 5, MONTH_JUNE = 6,
   MONTH_JULY = 7, MONTH_AUGUST = 8, MONTH_SEPTEMBER = 9,
   MONTH_OCTOBER = 10, MONTH_NOVEMBER = 11, MONTH_DECEMBER = 12
  };

enum ENUM_YEAR_SELECTION
  {
   YEAR_2020 = 2020, YEAR_2021 = 2021, YEAR_2022 = 2022, YEAR_2023 = 2023,
   YEAR_2024 = 2024, YEAR_2025 = 2025, YEAR_2026 = 2026, YEAR_2027 = 2027,
   YEAR_2028 = 2028, YEAR_2029 = 2029, YEAR_2030 = 2030, YEAR_CURRENT = 0
  };

//--- Input parameters
sinput string  s1 = "=== DISPLAY SETTINGS ===";
input ENUM_CALENDAR_POSITION CalendarPosition = POS_TOP_LEFT;
input int      CellWidth = 31;
input int      FontSize = 8;
input bool     ShowCellBorders = true;

sinput string  s2 = "=== TIME SETTINGS ===";
input bool     ShowWeekends = false;

sinput string  s3 = "=== FEATURES ===";
input bool     ShowWeekTotals = true;
input bool     ShowDates = false;
input bool     IncludeOpenPnL = true;

sinput string  s4 = "=== ADVANCED ===";
input bool     ShowZeroDays = true;
input double   MinPnLToShow = 1;
input int      DecimalPlaces = 0;
input int      XDistance = 3;
input int      YDistance = 80;

//--- Global variables
string prefix = "PnL_Cal_";
int display_month, display_year, current_day = 0;
int calendar_columns, cell_height, header_height, title_height;
double daily_pnl[], weekly_totals[], month_total = 0;
datetime month_start, month_end;
int arrow_width = 20, arrow_height = 20;
bool year_view_mode = false;  // Toggle between month and year view
double yearly_totals[12];     // Store monthly totals for year view

// Structure to hold calendar cell information
struct CalendarCell
  {
   int day;              // Day of month (1-31)
   int row;              // Row in calendar grid
   int col;              // Column in calendar grid
   int day_of_week;      // 0=Mon, 1=Tue, ..., 6=Sun
  };

CalendarCell calendar_cells[];

color BackgroundColor, BorderColor, HeaderBgColor, CurrentDayColor;
color HeaderTextColor, ProfitTextColor, LossTextColor, BreakevenColor;

//+------------------------------------------------------------------+
int OnInit()
  {
   LoadChartColors();
   calendar_columns = ShowWeekends ? 7 : 5;
   if(ShowWeekTotals) calendar_columns++;
   
   cell_height = CellWidth/2;
   header_height = cell_height;
   title_height = (int)(cell_height * 1.8);
   
   SetDisplayPeriod();
   CreateCalendar();
   EventSetTimer(1);  // Always update every second
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteAllObjects();
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateCalendar();
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
void LoadChartColors()
  {
   BackgroundColor = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   BorderColor = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   HeaderBgColor = (color)ChartGetInteger(0, CHART_COLOR_GRID);
   CurrentDayColor = (color)ChartGetInteger(0, CHART_COLOR_GRID);
   HeaderTextColor = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   BreakevenColor = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   
   ProfitTextColor = clrDodgerBlue;
   LossTextColor = clrCrimson;
  }

//+------------------------------------------------------------------+
void SetDisplayPeriod()
  {
   datetime current = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current, dt);

   // Always start with current month
   current_day = dt.day;
   display_month = dt.mon;
   display_year = dt.year;

   month_start = StringToTime(StringFormat("%04d.%02d.01", display_year, display_month));
   int next_month = display_month + 1, next_year = display_year;
   if(next_month > 12) { next_month = 1; next_year++; }
   month_end = StringToTime(StringFormat("%04d.%02d.01", next_year, next_month)) - 1;
  }

//+------------------------------------------------------------------+
double CalculateTodaysTotalPnL()
  {
   double total_pnl = 0.0;
   datetime today_start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime today_end = today_start + 86400 - 1;

   if(HistorySelect(today_start, today_end))
     {
      for(int i = 0; i < HistoryDealsTotal(); i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;

         // Always exclude deposits/withdrawals
         if((ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BALANCE)
            continue;

         total_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
     }

   if(IncludeOpenPnL)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
            total_pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
     }

   return total_pnl;
  }

//+------------------------------------------------------------------+
// Build calendar layout mapping each day to grid position
void BuildCalendarLayout()
  {
   int days_in_month = GetDaysInMonth(display_month, display_year);
   MqlDateTime dt;
   TimeToStruct(month_start, dt);
   
   ArrayResize(calendar_cells, 0);
   
   int row = 0, col = 0;
   int cols_per_week = ShowWeekends ? 7 : 5;
   
   for(int day = 1; day <= days_in_month; day++)
     {
      datetime day_time = month_start + (day - 1) * 86400;
      MqlDateTime day_dt;
      TimeToStruct(day_time, day_dt);
      
      // day_of_week: 0=Sunday, 1=Monday, ..., 6=Saturday
      int dow = day_dt.day_of_week;
      
      // Skip weekends if not showing them
      if(!ShowWeekends && (dow == 0 || dow == 6))
         continue;
      
      // Convert to our calendar system (0=Monday)
      int calendar_dow;
      if(ShowWeekends)
        {
         calendar_dow = (dow == 0) ? 6 : dow - 1;  // Mon=0, Tue=1, ..., Sun=6
        }
      else
        {
         calendar_dow = dow - 1;  // Mon=0, Tue=1, ..., Fri=4
        }
      
      // For first day, set starting column
      if(ArraySize(calendar_cells) == 0)
        {
         col = calendar_dow;
        }
      
      // Add cell to array
      int idx = ArraySize(calendar_cells);
      ArrayResize(calendar_cells, idx + 1);
      calendar_cells[idx].day = day;
      calendar_cells[idx].row = row;
      calendar_cells[idx].col = col;
      calendar_cells[idx].day_of_week = calendar_dow;
      
      // Move to next position
      col++;
      if(col >= cols_per_week)
        {
         col = 0;
         row++;
        }
     }
  }

//+------------------------------------------------------------------+
int GetTotalRows()
  {
   if(ArraySize(calendar_cells) == 0) return 1;
   
   int max_row = 0;
   for(int i = 0; i < ArraySize(calendar_cells); i++)
     {
      if(calendar_cells[i].row > max_row)
         max_row = calendar_cells[i].row;
     }
   
   return max_row + 1;
  }

//+------------------------------------------------------------------+
void CreateYearView()
  {
   CalculateYearlyTotals();
   
   // Use original calendar width
   int cols = ShowWeekends ? 7 : 5;
   if(ShowWeekTotals) cols++;
   
   int month_cols = 3;
   int month_rows = 4;
   int month_cell_width = (CellWidth * cols) / month_cols;
   int month_cell_height = cell_height * 2;  // Make cells taller for year view
   
   int table_width = month_cell_width * month_cols;
   int table_height = month_cell_height * month_rows;
   int total_width = table_width;
   int total_height = title_height + table_height;

   int x, y;
   CalculatePosition(x, y, total_width, total_height);

   // Main background
   CreateRect(prefix + "MainBG", x, y, x + total_width, y + total_height,
              BackgroundColor, BorderColor, 1);

   // Title background
   CreateRect(prefix + "TitleBG", x, y, x + total_width, y + title_height,
              HeaderBgColor, BorderColor, 1);

   // Navigation arrows
   int arrow_y = y + (title_height - arrow_height) / 2;
   CreateArrow(prefix + "LeftArrow", x + 5, arrow_y, true);
   CreateArrow(prefix + "RightArrow", x + total_width - arrow_width - 5, arrow_y, false);

   // Year header text
   string header_text = IntegerToString(display_year) + " ";
   CreateLabel(prefix + "Header", header_text, 
               x + arrow_width + 13,
               y + title_height/2, FontSize + 3, HeaderTextColor, ANCHOR_LEFT);
   
   // Create invisible clickable header area
   CreateRect(prefix + "HeaderClickArea", x + arrow_width + 5, y + 2,
             x + total_width - arrow_width - 5, y + title_height - 2,
             clrNONE, clrNONE, 0);

   // Year total
   double year_total = 0.0;
   for(int i = 0; i < 12; i++)
      year_total += yearly_totals[i];
   
   string total_text = "$ " + DoubleToString(year_total, DecimalPlaces);
   color total_color = (year_total > 0) ? ProfitTextColor :
                      (year_total < 0) ? LossTextColor : BreakevenColor;
   CreateLabel(prefix + "YearTotal", total_text,
              x + total_width - arrow_width - 13, y + title_height/2,
              FontSize + 3, total_color, ANCHOR_RIGHT);

   // Month cells
   string month_names[] = {"1", "2", "3", "4", "5", "6",
                           "7", "8", "9", "10", "11", "12"};
   
   int border_width = ShowCellBorders ? 1 : 0;
   int table_start_y = y + title_height;
   
   MqlDateTime current_dt;
   TimeToStruct(TimeCurrent(), current_dt);
   int current_month = current_dt.mon;
   int current_year = current_dt.year;
   
   for(int i = 0; i < 12; i++)
     {
      int row = i / month_cols;
      int col = i % month_cols;
      int cell_x = x + col * month_cell_width;
      int cell_y = table_start_y + row * month_cell_height;
      
      bool is_current = (i + 1 == current_month && display_year == current_year);
      color bg = is_current ? CurrentDayColor : BackgroundColor;
      
      CreateRect(prefix + "MonthCell_" + IntegerToString(i),
                cell_x, cell_y, cell_x + month_cell_width, cell_y + month_cell_height,
                bg, BorderColor, border_width);
      
      // Month name
      CreateLabel(prefix + "MonthName_" + IntegerToString(i), month_names[i],
                 cell_x + month_cell_width/6, cell_y,
                 FontSize, HeaderTextColor, ANCHOR_UPPER);
      
      // Month PnL
      double pnl = yearly_totals[i];
      if(MathAbs(pnl) >= MinPnLToShow || ShowZeroDays)
        {
         string pnl_text = DoubleToString(pnl, DecimalPlaces);
         color text_color = (pnl > 0) ? ProfitTextColor :
                           (pnl < 0) ? LossTextColor : BreakevenColor;
         
         CreateLabel(prefix + "MonthPnL_" + IntegerToString(i), pnl_text,
                    cell_x + month_cell_width/2, cell_y + month_cell_height/2 ,
                    FontSize+3, text_color, ANCHOR_CENTER);
        }
     }
  }

//+------------------------------------------------------------------+
void CalculateYearlyTotals()
  {
   ArrayInitialize(yearly_totals, 0.0);
   
   datetime year_start = StringToTime(StringFormat("%04d.01.01", display_year));
   datetime year_end = StringToTime(StringFormat("%04d.12.31 23:59:59", display_year));
   
   if(!HistorySelect(year_start, year_end)) return;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      // Always exclude deposits/withdrawals
      if((ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BALANCE)
         continue;
      
      datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                     HistoryDealGetDouble(ticket, DEAL_SWAP) +
                     HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      
      MqlDateTime deal_dt;
      TimeToStruct(deal_time, deal_dt);
      
      if(deal_dt.year == display_year && deal_dt.mon >= 1 && deal_dt.mon <= 12)
        {
         yearly_totals[deal_dt.mon - 1] += profit;
        }
     }
   
   // Add open PnL to current month if viewing current year
   MqlDateTime current_dt;
   TimeToStruct(TimeCurrent(), current_dt);
   
   if(display_year == current_dt.year && IncludeOpenPnL)
     {
      double open_pnl = 0.0;
      for(int i = 0; i < PositionsTotal(); i++)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
            open_pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
      yearly_totals[current_dt.mon - 1] += open_pnl;
     }
  }

//+------------------------------------------------------------------+
void UpdateYearView()
  {
   CalculateYearlyTotals();
   
   // Use same width calculations as CreateYearView
   int cols = ShowWeekends ? 7 : 5;
   if(ShowWeekTotals) cols++;
   
   int month_cols = 3;
   int month_rows = 4;
   int month_cell_width = (CellWidth * cols) / month_cols;
   int month_cell_height = cell_height * 2;
   
   int total_width = month_cell_width * month_cols;
   int total_height = title_height + month_cell_height * month_rows;
   int x, y;
   CalculatePosition(x, y, total_width, total_height);

   // Update year total
   double year_total = 0.0;
   for(int i = 0; i < 12; i++)
      year_total += yearly_totals[i];
   
   string total_text = "$ " + DoubleToString(year_total, DecimalPlaces);
   color total_color = (year_total > 0) ? ProfitTextColor :
                      (year_total < 0) ? LossTextColor : BreakevenColor;
   
   ObjectDelete(0, prefix + "YearTotal");
   CreateLabel(prefix + "YearTotal", total_text,
              x + total_width - arrow_width - 13, y + title_height/2,
              FontSize + 3, total_color, ANCHOR_RIGHT);

   // Update month PnL values
   int table_start_y = y + title_height;
   
   for(int i = 0; i < 12; i++)
     {
      double pnl = yearly_totals[i];
      
      ObjectDelete(0, prefix + "MonthPnL_" + IntegerToString(i));
      
      if(MathAbs(pnl) >= MinPnLToShow || ShowZeroDays)
        {
         string pnl_text = DoubleToString(pnl, DecimalPlaces);
         color text_color = (pnl > 0) ? ProfitTextColor :
                           (pnl < 0) ? LossTextColor : BreakevenColor;
         
         int row = i / month_cols;
         int col = i % month_cols;
         int cell_x = x + col * month_cell_width;
         int cell_y = table_start_y + row * month_cell_height;
         
         CreateLabel(prefix + "MonthPnL_" + IntegerToString(i), pnl_text,
                    cell_x + month_cell_width/2, cell_y + month_cell_height/2 ,
                    FontSize+3, text_color, ANCHOR_CENTER);
        }
     }
   
   ChartRedraw();
  }

//+------------------------------------------------------------------+
void CreateCalendar()
  {
   DeleteAllObjects();
   
   if(year_view_mode)
     {
      CreateYearView();
      return;
     }
   
   BuildCalendarLayout();

   int weeks_needed = GetTotalRows();
   int cols = ShowWeekends ? 7 : 5;
   int table_width = CellWidth * calendar_columns;
   int table_height = header_height + cell_height * weeks_needed;
   int total_width = table_width;
   int total_height = title_height + table_height;

   int x, y;
   CalculatePosition(x, y, total_width, total_height);

   // Main background
   CreateRect(prefix + "MainBG", x, y, x + total_width, y + total_height,
              BackgroundColor, BorderColor, 1);

   // Title background
   CreateRect(prefix + "TitleBG", x, y, x + total_width, y + title_height,
              HeaderBgColor, BorderColor, 1);

   // Navigation arrows
   int arrow_y = y + (title_height - arrow_height) / 2;
   CreateArrow(prefix + "LeftArrow", x + 5, arrow_y, true);
   CreateArrow(prefix + "RightArrow", x + total_width - arrow_width - 5, arrow_y, false);

   // Month/Year header
   string month_names[] = {"", "1", "2", "3", "4", "5", "6",
                           "7", "8", "9", "10", "11", "12"};
   string header_text = month_names[display_month] + "/" + IntegerToString(display_year);
   CreateLabel(prefix + "Header", header_text, 
               x + arrow_width + 13,
               y + title_height/2, FontSize + 3, HeaderTextColor, ANCHOR_LEFT);
   
   // Create invisible clickable area for header (between arrows)
   CreateRect(prefix + "HeaderClickArea", x + arrow_width + 5, y + 2,
             x + total_width - arrow_width - 5, y + title_height - 2,
             clrNONE, clrNONE, 0);

   // Day headers
   string day_names[];
   if(ShowWeekends)
     {
      string temp[] = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
      ArrayCopy(day_names, temp);
     }
   else
     {
      string temp[] = {"Mon", "Tue", "Wed", "Thu", "Fri"};
      ArrayCopy(day_names, temp);
     }
   
   int table_start_y = y + title_height;

   for(int i = 0; i < cols; i++)
     {
      int header_x = x + i * CellWidth;
      CreateRect(prefix + "DayHeaderBG_" + IntegerToString(i),
                 header_x, table_start_y, header_x + CellWidth, table_start_y + header_height,
                 HeaderBgColor, BorderColor, 1);
      
      CreateLabel(prefix + "DayHeader_" + IntegerToString(i), day_names[i],
                  header_x + CellWidth/2, table_start_y + header_height/2,
                  FontSize, HeaderTextColor, ANCHOR_CENTER);
     }

   // Week totals header
   if(ShowWeekTotals)
     {
      int week_x = x + cols * CellWidth;
      
      // Add separator line if borders are hidden
      if(!ShowCellBorders)
        {
         CreateRect(prefix + "TotalSeparator", week_x - 1, table_start_y,
                   week_x, table_start_y + header_height + cell_height * weeks_needed,
                   BorderColor, BorderColor, 1);
        }
      
      CreateRect(prefix + "WeekHeaderBG", week_x, table_start_y,
                 week_x + CellWidth, table_start_y + header_height,
                 HeaderBgColor, BorderColor, 1);
      
      CreateLabel(prefix + "WeekHeader", "Total", week_x + CellWidth/2,
                  table_start_y + header_height/2, FontSize, HeaderTextColor, ANCHOR_CENTER);
     }

   FillCalendarCells(x, table_start_y + header_height, cols, weeks_needed);
  }

//+------------------------------------------------------------------+
void CreateArrow(string name, int x, int y, bool is_left)
  {
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, arrow_width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, arrow_height);
   ObjectSetString(0, name, OBJPROP_TEXT, is_left ? "<" : ">");
   ObjectSetString(0, name, OBJPROP_FONT, "Calibri");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize + 2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, HeaderTextColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, HeaderBgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, BorderColor);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }

//+------------------------------------------------------------------+
void FillCalendarCells(int start_x, int start_y, int cols, int total_rows)
  {
   int border_width = ShowCellBorders ? 1 : 0;
   
   // Create all cells first (empty grid)
   for(int row = 0; row < total_rows; row++)
     {
      for(int col = 0; col < cols; col++)
        {
         int cell_x = start_x + col * CellWidth;
         int cell_y = start_y + row * cell_height;
         
         CreateRect(prefix + "Cell_" + IntegerToString(row) + "_" + IntegerToString(col),
                   cell_x, cell_y, cell_x + CellWidth, cell_y + cell_height,
                   BackgroundColor, BorderColor, border_width);
        }
      
      // Week total cells
      if(ShowWeekTotals)
        {
         int week_x = start_x + cols * CellWidth;
         int week_y = start_y + row * cell_height;
         
         CreateRect(prefix + "WeekCell_" + IntegerToString(row),
                   week_x, week_y, week_x + CellWidth, week_y + cell_height,
                   BackgroundColor, BorderColor, border_width);
        }
     }
   
   // Now mark cells with days
   for(int i = 0; i < ArraySize(calendar_cells); i++)
     {
      int day = calendar_cells[i].day;
      int row = calendar_cells[i].row;
      int col = calendar_cells[i].col;
      
      MqlDateTime current_dt;
      TimeToStruct(TimeCurrent(), current_dt);
      bool is_today = (day == current_day && 
                       display_month == current_dt.mon && 
                       display_year == current_dt.year);
      color bg = is_today ? CurrentDayColor : BackgroundColor;
      
      int cell_x = start_x + col * CellWidth;
      int cell_y = start_y + row * cell_height;
      
      // Recreate cell with proper background
      CreateRect(prefix + "Cell_" + IntegerToString(row) + "_" + IntegerToString(col),
                cell_x, cell_y, cell_x + CellWidth, cell_y + cell_height,
                bg, BorderColor, border_width);
      
      // Add date number if enabled
      if(ShowDates)
        {
         CreateLabel(prefix + "Date_" + IntegerToString(day),
                    IntegerToString(day), cell_x + 3, cell_y + 2,
                    FontSize - 1, clrGray, ANCHOR_LEFT_UPPER);
        }
     }
  }

//+------------------------------------------------------------------+
void UpdateCalendar()
  {
   if(year_view_mode)
     {
      UpdateYearView();
      return;
     }
   
   CalculateDailyPnL();

   int cols = ShowWeekends ? 7 : 5;
   int weeks_needed = GetTotalRows();
   
   int total_width = CellWidth * calendar_columns;
   int total_height = title_height + header_height + cell_height * weeks_needed;
   int x, y;
   CalculatePosition(x, y, total_width, total_height);

   // Update month total (always shown)
   string total_text = "$ " + DoubleToString(month_total, DecimalPlaces);
   color total_color = (month_total > 0) ? ProfitTextColor :
                      (month_total < 0) ? LossTextColor : BreakevenColor;

   ObjectDelete(0, prefix + "MonthTotal");
   CreateLabel(prefix + "MonthTotal", total_text,
              x + total_width - arrow_width - 13, y + title_height/2,
              FontSize + 3, total_color, ANCHOR_RIGHT);

   // Calculate weekly totals
   if(ShowWeekTotals)
     {
      ArrayResize(weekly_totals, weeks_needed);
      ArrayInitialize(weekly_totals, 0.0);
      
      for(int i = 0; i < ArraySize(calendar_cells); i++)
        {
         int day = calendar_cells[i].day;
         int row = calendar_cells[i].row;
         
         double pnl = 0.0;
         if(day <= ArraySize(daily_pnl))
           {
            pnl = daily_pnl[day - 1];
            if(day == current_day) pnl = CalculateTodaysTotalPnL();
           }
         
         weekly_totals[row] += pnl;
        }
     }

   int table_start_y = y + title_height + header_height;

   // Update PnL values
   for(int i = 0; i < ArraySize(calendar_cells); i++)
     {
      int day = calendar_cells[i].day;
      int row = calendar_cells[i].row;
      int col = calendar_cells[i].col;
      
      double pnl = 0.0;
      if(day <= ArraySize(daily_pnl))
        {
         pnl = daily_pnl[day - 1];
         if(day == current_day) pnl = CalculateTodaysTotalPnL();
        }

      if(MathAbs(pnl) >= MinPnLToShow || ShowZeroDays)
        {
         string pnl_text = DoubleToString(pnl, DecimalPlaces);
         color text_color = (pnl > 0) ? ProfitTextColor :
                           (pnl < 0) ? LossTextColor : BreakevenColor;

         int cell_x = x + col * CellWidth;
         int cell_y = table_start_y + row * cell_height;
         int text_y = ShowDates ? cell_y + cell_height - 3 : cell_y + cell_height/2;
         ENUM_ANCHOR_POINT anchor = ShowDates ? ANCHOR_LOWER : ANCHOR_CENTER;

         ObjectDelete(0, prefix + "PnL_" + IntegerToString(day));
         CreateLabel(prefix + "PnL_" + IntegerToString(day), pnl_text,
                    cell_x + CellWidth/2, text_y, FontSize, text_color, anchor);
        }
     }

   // Update week totals
   if(ShowWeekTotals)
     {
      for(int week = 0; week < weeks_needed; week++)
        {
         double week_total = weekly_totals[week];
         if(MathAbs(week_total) >= MinPnLToShow || ShowZeroDays)
           {
            string week_text = DoubleToString(week_total, DecimalPlaces);
            color week_color = (week_total > 0) ? ProfitTextColor :
                              (week_total < 0) ? LossTextColor : BreakevenColor;

            int week_x = x + cols * CellWidth;
            int week_y = table_start_y + week * cell_height;

            ObjectDelete(0, prefix + "WeekTotal_" + IntegerToString(week));
            CreateLabel(prefix + "WeekTotal_" + IntegerToString(week), week_text,
                       week_x + CellWidth/2, week_y + cell_height/2,
                       FontSize, week_color, ANCHOR_CENTER);
           }
        }
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
void CalculateDailyPnL()
  {
   int days_in_month = GetDaysInMonth(display_month, display_year);
   ArrayResize(daily_pnl, days_in_month);
   ArrayInitialize(daily_pnl, 0.0);
   month_total = 0.0;

   if(!HistorySelect(month_start, month_end)) return;

   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // Always exclude deposits/withdrawals
      if((ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BALANCE)
         continue;

      datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                     HistoryDealGetDouble(ticket, DEAL_SWAP) +
                     HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      MqlDateTime deal_dt;
      TimeToStruct(deal_time, deal_dt);

      if(deal_dt.year == display_year && deal_dt.mon == display_month)
        {
         int day_index = deal_dt.day - 1;
         if(day_index >= 0 && day_index < days_in_month)
           {
            daily_pnl[day_index] += profit;
            month_total += profit;
           }
        }
     }

   if(current_day > 0 && IncludeOpenPnL)
     {
      double open_pnl = 0.0;
      for(int i = 0; i < PositionsTotal(); i++)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
            open_pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
      month_total += open_pnl;
     }
  }

//+------------------------------------------------------------------+
void CalculatePosition(int &x, int &y, int width, int height)
  {
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   switch(CalendarPosition)
     {
      case POS_TOP_LEFT: x = XDistance; y = YDistance; break;
      case POS_TOP_RIGHT: x = chart_width - width - XDistance; y = YDistance; break;
      case POS_BOTTOM_LEFT: x = XDistance; y = chart_height - height - YDistance; break;
      case POS_BOTTOM_RIGHT: x = chart_width - width - XDistance; y = chart_height - height - YDistance; break;
     }
  }

//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int font_size, color clr,
                ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Calibri");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void CreateRect(string name, int x1, int y1, int x2, int y2, color bg_color,
               color border_color, int border_width)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, x2 - x1);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, y2 - y1);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
int GetDaysInMonth(int month, int year)
  {
   int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
   if(month == 2 && ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)))
      return 29;
   return days[month - 1];
  }

//+------------------------------------------------------------------+
void DeleteAllObjects()
  {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0) ObjectDelete(0, name);
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == prefix + "LeftArrow")
        {
         if(year_view_mode)
           {
            display_year--;
            CreateCalendar();
           }
         else
            NavigateMonth(-1);
         ObjectSetInteger(0, prefix + "LeftArrow", OBJPROP_STATE, false);
        }
      else if(sparam == prefix + "RightArrow")
        {
         if(year_view_mode)
           {
            display_year++;
            CreateCalendar();
           }
         else
            NavigateMonth(1);
         ObjectSetInteger(0, prefix + "RightArrow", OBJPROP_STATE, false);
        }
      else if(sparam == prefix + "HeaderClickArea")
        {
         // Toggle between month and year view
         year_view_mode = !year_view_mode;
         CreateCalendar();
         ObjectSetInteger(0, prefix + "HeaderClickArea", OBJPROP_STATE, false);
        }
     }
  }

//+------------------------------------------------------------------+
void NavigateMonth(int direction)
  {
   display_month += direction;
   if(display_month > 12) { display_month = 1; display_year++; }
   else if(display_month < 1) { display_month = 12; display_year--; }
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   current_day = (display_month == dt.mon && display_year == dt.year) ? dt.day : 0;
   
   month_start = StringToTime(StringFormat("%04d.%02d.01", display_year, display_month));
   int next_month = display_month + 1, next_year = display_year;
   if(next_month > 12) { next_month = 1; next_year++; }
   month_end = StringToTime(StringFormat("%04d.%02d.01", next_year, next_month)) - 1;
   
   CreateCalendar();
  }
//+------------------------------------------------------------------+
