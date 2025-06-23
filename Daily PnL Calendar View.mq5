//+------------------------------------------------------------------+
//|                              smaGUY_Daily_PnL_Calendar_View.mq5  |
//|                               Daily P&L Calendar View Indicator  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025 SmaGUY"
#property version   "1.40"
#property description "Daily PnL on a monthly calendar view with enhanced features"
#property indicator_chart_window
#property indicator_plots 0

//--- Enums
enum ENUM_CALENDAR_POSITION
  {
   POS_TOP_LEFT = 0,      // Top Left
   POS_TOP_RIGHT = 1,     // Top Right
   POS_BOTTOM_LEFT = 2,   // Bottom Left
   POS_BOTTOM_RIGHT = 3   // Bottom Right
  };

enum ENUM_MONTH_SELECTION
  {
   MONTH_CURRENT = 0,     // Current Month
   MONTH_JANUARY = 1,     // January
   MONTH_FEBRUARY = 2,    // February
   MONTH_MARCH = 3,       // March
   MONTH_APRIL = 4,       // April
   MONTH_MAY = 5,         // May
   MONTH_JUNE = 6,        // June
   MONTH_JULY = 7,        // July
   MONTH_AUGUST = 8,      // August
   MONTH_SEPTEMBER = 9,   // September
   MONTH_OCTOBER = 10,    // October
   MONTH_NOVEMBER = 11,   // November
   MONTH_DECEMBER = 12    // December
  };

enum ENUM_YEAR_SELECTION
  {
   YEAR_2020 = 2020, YEAR_2021 = 2021, YEAR_2022 = 2022, YEAR_2023 = 2023,
   YEAR_2024 = 2024, YEAR_2025 = 2025, YEAR_2026 = 2026, YEAR_2027 = 2027,
   YEAR_2028 = 2028, YEAR_2029 = 2029, YEAR_2030 = 2030, YEAR_CURRENT = 0
  };

//--- Input parameters
sinput string  s1 = "=== DISPLAY SETTINGS ===";
input ENUM_CALENDAR_POSITION CalendarPosition = POS_BOTTOM_LEFT; // Calendar Position
input int      CellWidth = 35;                          // Cell Width (Height auto-calculated)
input int      FontSize = 8;                            // Font Size

sinput string  s2 = "=== TIME SETTINGS ===";
input ENUM_MONTH_SELECTION MonthToShow = MONTH_CURRENT; // Month to Display
input ENUM_YEAR_SELECTION YearToShow = YEAR_CURRENT;   // Year to Display
input bool     ShowWeekends = false;                   // Show Weekend Days

sinput string  s3 = "=== FEATURES ===";
input bool     ShowWeekTotals = true;                  // Show Weekly Totals Column
input bool     ShowMonthTotal = true;                  // Show Month Total in Header
input bool     ShowDates = false;                      // Show Date Numbers in Cells
input bool     HighlightCurrentDay = true;             // Highlight Current Day
input bool     IncludeOpenPnL = true;                  // Include Currently Open P&L

sinput string  s4 = "=== COLORS ===";
input color    BackgroundColor = clrWhite;       // Background Color
input color    BorderColor = clrDarkGray;           // Border Color
input color    HeaderBgColor = clrLightGray;         // Header Background
input color    HeaderTextColor = clrBlack;             // Header Text Color
input color    ProfitTextColor = clrBlue;              // Profit Text Color
input color    LossTextColor = clrRed;                 // Loss Text Color
input color    BreakevenColor = clrDarkGray;               // Breakeven Color
input color    CurrentDayColor = clrLightGray;       // Current Day Background
input color    WeekTotalColor = clrPurple;             // Week Total Color

sinput string  s5 = "=== ADVANCED ===";
input bool     ShowZeroDays = true;                    // Show Days with Zero P&L
input double   MinPnLToShow = 1;                       // Minimum P&L to Display
input int      DecimalPlaces = 0;                      // Decimal Places for P&L
input bool     ExcludeDepositsWithdrawals = true;      // Exclude Deposits/Withdrawals
input int      XDistance = 0;                          // Distance from Left/Right Edge
input int      YDistance = 0;                          // Distance from Top/Bottom Edge

//--- Global variables
string prefix = "PnL_Cal_";
int display_month, display_year, current_day = 0;
int calendar_columns, cell_height, header_height, title_height;
double daily_pnl[], weekly_totals[], month_total = 0;
datetime month_start, month_end;
int arrow_width = 20;
int arrow_height = 20;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   calendar_columns = ShowWeekends ? 7 : 5;
   if(ShowWeekTotals)
      calendar_columns++;

// Estimate text height using FontSize and font
   //uint text_width, text_height;
   //TextGetSize("123", text_width, text_height); // "Ag" gives decent height estimate

   cell_height = CellWidth/2 + 0;  // Add padding if needed
   header_height = cell_height;
   title_height = (int)(cell_height * 1.8);

   SetDisplayPeriod();
   CreateCalendar();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinitialization                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteAllObjects();
  }

//+------------------------------------------------------------------+
//| Main calculation function                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[])
  {
   UpdateCalendar();
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Set display period                                              |
//+------------------------------------------------------------------+
void SetDisplayPeriod()
  {
   datetime current = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current, dt);

// Set current day for highlighting
   if(MonthToShow == MONTH_CURRENT && (YearToShow == YEAR_CURRENT || YearToShow == dt.year))
      current_day = dt.day;
   else
      current_day = 0;

// Set month and year
   display_month = (MonthToShow == MONTH_CURRENT) ? dt.mon : (int)MonthToShow;
   display_year = (YearToShow == YEAR_CURRENT) ? dt.year : (int)YearToShow;

// Calculate month boundaries
   month_start = StringToTime(StringFormat("%04d.%02d.01", display_year, display_month));
   int next_month = display_month + 1, next_year = display_year;
   if(next_month > 12)
     {
      next_month = 1;
      next_year++;
     }
   month_end = StringToTime(StringFormat("%04d.%02d.01", next_year, next_month)) - 1;
  }

//+------------------------------------------------------------------+
//| Calculate current open P&L including today's closed trades      |
//+------------------------------------------------------------------+
double CalculateTodaysTotalPnL()
  {
   double total_pnl = 0.0;
   datetime today_start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime today_end = today_start + 86400 - 1; // End of today

// Get today's closed trades
   if(HistorySelect(today_start, today_end))
     {
      int deals_total = HistoryDealsTotal();
      for(int i = 0; i < deals_total; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;

         if(ExcludeDepositsWithdrawals)
           {
            ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
            if(deal_type == DEAL_TYPE_BALANCE)
               continue;
           }

         total_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        }
     }

// Add current open positions P&L
   if(IncludeOpenPnL)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
           {
            total_pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
           }
        }
     }

   return total_pnl;
  }

//+------------------------------------------------------------------+
//| MODIFIED: Update CreateCalendar function - Add arrow creation   |
//+------------------------------------------------------------------+
void CreateCalendar()
  {
   DeleteAllObjects();

   const int BORDER_WIDTH = 1;
   const int TABLE_WIDTH = CellWidth * calendar_columns;
   int weeks_needed = CalculateWeeksInMonth();
   const int TABLE_HEIGHT = header_height + cell_height * weeks_needed;
   const int TOTAL_WIDTH = TABLE_WIDTH + (BORDER_WIDTH * 2);
   const int TOTAL_HEIGHT = title_height + TABLE_HEIGHT + BORDER_WIDTH;

   int x, y;
   CalculatePosition(x, y, TOTAL_WIDTH, TOTAL_HEIGHT);

   // Main background
   CreateRectangle(prefix + "MainBG", x, y, x + TOTAL_WIDTH, y + TOTAL_HEIGHT,
                   BackgroundColor, BorderColor, BORDER_WIDTH);

   // Title background
   CreateRectangle(prefix + "TitleBG", x + BORDER_WIDTH, y + BORDER_WIDTH,
                   x + TOTAL_WIDTH - BORDER_WIDTH, y + title_height,
                   HeaderBgColor, BorderColor, 1);

   // NEW: Create navigation arrows
   int arrow_y = y + BORDER_WIDTH + (title_height - arrow_height) / 2;
   int left_arrow_x = x + BORDER_WIDTH + 5;
   int right_arrow_x = x + TOTAL_WIDTH - BORDER_WIDTH - arrow_width - 5;
   
   CreateNavigationArrow(prefix + "LeftArrow", left_arrow_x, arrow_y, true);
   CreateNavigationArrow(prefix + "RightArrow", right_arrow_x, arrow_y, false);

   // Month header
   string month_names[] = {"", "January", "February", "March", "April", "May", "June",
                           "July", "August", "September", "October", "November", "December"
                          };
   string header_text = month_names[display_month] + " " + IntegerToString(display_year);

   CreateLabel(prefix + "Header", header_text, x + (ShowMonthTotal ? left_arrow_x + arrow_width + 8 : TOTAL_WIDTH/2),
               y + title_height/2, FontSize + 3, HeaderTextColor,
               ShowMonthTotal ? ANCHOR_LEFT : ANCHOR_CENTER);
// Day headers
   string day_names[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
   string business_days[] = {"Mon", "Tue", "Wed", "Thu", "Fri"};

   int table_start_x = x + BORDER_WIDTH;
   int table_start_y = y + title_height;
   int cols = ShowWeekends ? 7 : 5;

   for(int i = 0; i < cols; i++)
     {
      string day_name = ShowWeekends ? day_names[i] : business_days[i];

      CreateRectangle(prefix + "DayHeaderBG_" + IntegerToString(i),
                      table_start_x + i * CellWidth, table_start_y,
                      table_start_x + (i + 1) * CellWidth, table_start_y + header_height,
                      HeaderBgColor, BorderColor, 1);

      CreateLabel(prefix + "DayHeader_" + IntegerToString(i), day_name,
                  table_start_x + i * CellWidth + CellWidth/2, table_start_y + header_height/2,
                  FontSize, HeaderTextColor, ANCHOR_CENTER);
     }

// Week total header
   if(ShowWeekTotals)
     {
      CreateRectangle(prefix + "WeekHeaderBG",
                      table_start_x + cols * CellWidth, table_start_y,
                      table_start_x + (cols + 1) * CellWidth, table_start_y + header_height,
                      HeaderBgColor, BorderColor, 1);

      CreateLabel(prefix + "WeekHeader", "Total",
                  table_start_x + cols * CellWidth + CellWidth/2, table_start_y + header_height/2,
                  FontSize, HeaderTextColor, ANCHOR_CENTER);
     }

   FillCalendarDates(table_start_x, table_start_y + header_height);
  }

//+------------------------------------------------------------------+
//| NEW: Add this function - Create navigation arrows               |
//+------------------------------------------------------------------+
void CreateNavigationArrow(string name, int x, int y, bool is_left)
  {
   ObjectDelete(0, name);
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
//| Fill calendar with dates                                        |
//+------------------------------------------------------------------+
void FillCalendarDates(int start_x, int start_y)
  {
   MqlDateTime dt;
   TimeToStruct(month_start, dt);

   int days_in_month = GetDaysInMonth(display_month, display_year);
   int first_day_of_week = dt.day_of_week;
   int cols = ShowWeekends ? 7 : 5;

// Adjust first day for business days
   if(!ShowWeekends)
     {
      first_day_of_week = (first_day_of_week == 0) ? 4 : first_day_of_week - 1;
      if(first_day_of_week > 4)
         first_day_of_week = 0;
     }

// Create date cells
   int day_counter = 1;
   int weeks_needed = CalculateWeeksInMonth();
   for(int week = 0; week < weeks_needed; week++)
     {
      for(int day_col = 0; day_col < cols; day_col++)
        {
         int cell_x = start_x + day_col * CellWidth;
         int cell_y = start_y + week * cell_height;

         bool should_show_date = (week == 0 && day_col >= first_day_of_week) ||
                                 (week > 0 && day_counter <= days_in_month);

         if(should_show_date && day_counter <= days_in_month)
           {
            bool is_current_day = (HighlightCurrentDay && day_counter == current_day);
            color bg_color = is_current_day ? CurrentDayColor : BackgroundColor;

            CreateRectangle(prefix + "Cell_" + IntegerToString(day_counter),
                            cell_x, cell_y, cell_x + CellWidth, cell_y + cell_height,
                            bg_color, BorderColor, is_current_day ? 2 : 1);

            if(ShowDates)
              {
               CreateLabel(prefix + "Date_" + IntegerToString(day_counter),
                           IntegerToString(day_counter), cell_x + 3, cell_y + 2,
                           FontSize - 1, clrGray, ANCHOR_LEFT_UPPER);
              }

            day_counter++;
           }
         else
           {
            CreateRectangle(prefix + "EmptyCell_" + IntegerToString(week) + "_" + IntegerToString(day_col),
                            cell_x, cell_y, cell_x + CellWidth, cell_y + cell_height,
                            BackgroundColor, BorderColor, 1);
           }
        }

      // Week total cells
      if(ShowWeekTotals)
        {
         int week_cell_x = start_x + cols * CellWidth;
         int week_cell_y = start_y + week * cell_height;

         CreateRectangle(prefix + "WeekCell_" + IntegerToString(week),
                         week_cell_x, week_cell_y, week_cell_x + CellWidth, week_cell_y + cell_height,
                         BackgroundColor, BorderColor, 1);
        }

      if(day_counter > days_in_month)
         break;
     }
  }

//+------------------------------------------------------------------+
//| Update calendar with P&L data                                   |
//+------------------------------------------------------------------+
void UpdateCalendar()
  {
   CalculateDailyPnL();

   int days_in_month = GetDaysInMonth(display_month, display_year);
   int cols = ShowWeekends ? 7 : 5;

// Calculate positions
   const int BORDER_WIDTH = 1;
   const int TOTAL_WIDTH = CellWidth * calendar_columns + (BORDER_WIDTH * 2);
   const int TOTAL_HEIGHT = title_height + header_height + cell_height * 7 + (BORDER_WIDTH * 2);

   int x, y;
   CalculatePosition(x, y, TOTAL_WIDTH, TOTAL_HEIGHT);

   int table_start_x = x + BORDER_WIDTH;
   int table_start_y = y + title_height + BORDER_WIDTH + header_height;

// Update month total in header
   if(ShowMonthTotal)
     {
      string month_total_text = "Total: " + DoubleToString(month_total, DecimalPlaces);
      color total_color = (month_total > 0) ? ProfitTextColor :
                          (month_total < 0) ? LossTextColor : BreakevenColor;

      ObjectDelete(0, prefix + "MonthTotal");
      CreateLabel(prefix + "MonthTotal", month_total_text,
                  x + TOTAL_WIDTH - arrow_width - 8 - 5, y + title_height/2,  // Adjusted position
                  FontSize + 3, total_color, ANCHOR_RIGHT);
     }
     
// Update daily P&L
   MqlDateTime dt;
   TimeToStruct(month_start, dt);
   int first_day_of_week = dt.day_of_week;

   if(!ShowWeekends)
     {
      first_day_of_week = (first_day_of_week == 0) ? 4 : first_day_of_week - 1;
      if(first_day_of_week > 4)
         first_day_of_week = 0;
     }

// Calculate weekly totals
   if(ShowWeekTotals)
     {
      ArrayResize(weekly_totals, 7);
      ArrayInitialize(weekly_totals, 0.0);
     }

   int day_counter = 1;
   for(int week = 0; week < 7; week++)
     {
      for(int day_col = 0; day_col < cols; day_col++)
        {
         bool should_show_date = (week == 0 && day_col >= first_day_of_week) ||
                                 (week > 0 && day_counter <= days_in_month);

         if(should_show_date && day_counter <= days_in_month && day_counter <= ArraySize(daily_pnl))
           {
            double pnl = daily_pnl[day_counter - 1];

            // Add today's total P&L (closed + open)
            if(day_counter == current_day)
               pnl = CalculateTodaysTotalPnL();

            if(ShowWeekTotals)
               weekly_totals[week] += pnl;

            if(MathAbs(pnl) >= MinPnLToShow || ShowZeroDays)
              {
               string pnl_text = DoubleToString(pnl, DecimalPlaces);
               color text_color = (pnl > 0) ? ProfitTextColor :
                                  (pnl < 0) ? LossTextColor : BreakevenColor;

               int cell_x = table_start_x + day_col * CellWidth;
               int cell_y = table_start_y + week * cell_height;
               int text_y = ShowDates ? cell_y + cell_height - 3 : cell_y + cell_height/2;
               ENUM_ANCHOR_POINT anchor = ShowDates ? ANCHOR_LOWER : ANCHOR_CENTER;

               ObjectDelete(0, prefix + "PnL_" + IntegerToString(day_counter));
               CreateLabel(prefix + "PnL_" + IntegerToString(day_counter), pnl_text,
                           cell_x + CellWidth/2, text_y, FontSize, text_color, anchor);
              }

            day_counter++;
           }
        }

      // Update week totals
      if(ShowWeekTotals && week < ArraySize(weekly_totals))
        {
         double week_total = weekly_totals[week];
         if(MathAbs(week_total) >= MinPnLToShow || ShowZeroDays)
           {
            string week_text = DoubleToString(week_total, DecimalPlaces);
            color week_color = (week_total > 0) ? ProfitTextColor :
                               (week_total < 0) ? LossTextColor : WeekTotalColor;

            int week_cell_x = table_start_x + cols * CellWidth;
            int week_cell_y = table_start_y + week * cell_height;

            ObjectDelete(0, prefix + "WeekTotal_" + IntegerToString(week));
            CreateLabel(prefix + "WeekTotal_" + IntegerToString(week), week_text,
                        week_cell_x + CellWidth/2, week_cell_y + cell_height/2,
                        FontSize, week_color, ANCHOR_CENTER);
           }
        }

      if(day_counter > days_in_month)
         break;
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Calculate daily P&L from history                                |
//+------------------------------------------------------------------+
void CalculateDailyPnL()
  {
   int days_in_month = GetDaysInMonth(display_month, display_year);
   ArrayResize(daily_pnl, days_in_month);
   ArrayInitialize(daily_pnl, 0.0);
   month_total = 0.0;

   if(!HistorySelect(month_start, month_end))
     {
      Print("Failed to select history for period: ", month_start, " to ", month_end);
      return;
     }

   int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(ExcludeDepositsWithdrawals)
        {
         ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(deal_type == DEAL_TYPE_BALANCE)
            continue;
        }

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

// Add today's open P&L to month total if it's current month
   if(current_day > 0 && IncludeOpenPnL)
     {
      double open_pnl = 0.0;
      for(int i = 0; i < PositionsTotal(); i++)
        {
         string symbol = PositionGetSymbol(i);
         if(symbol != "" && PositionSelectByTicket(PositionGetTicket(symbol)))
           {
            open_pnl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
           }
        }
      month_total += open_pnl;
     }
  }

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
void CalculatePosition(int &x, int &y, int width, int height)
  {
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   switch(CalendarPosition)
     {
      case POS_TOP_LEFT:
         x = XDistance;
         y = YDistance;
         break;
      case POS_TOP_RIGHT:
         x = chart_width - width - XDistance;
         y = YDistance;
         break;
      case POS_BOTTOM_LEFT:
         x = XDistance;
         y = chart_height - height - YDistance;
         break;
      case POS_BOTTOM_RIGHT:
         x = chart_width - width - XDistance;
         y = chart_height - height - YDistance;
         break;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int font_size, color clr,
                 ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER, string font = "Calibri")
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x1, int y1, int x2, int y2, color bg_color,
                     color border_color = clrNONE, int border_width = 0)
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
//|                                                                  |
//+------------------------------------------------------------------+
int GetDaysInMonth(int month, int year)
  {
   int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
   if(month == 2 && ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)))
      return 29;
   return days[month - 1];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteAllObjects()
  {
   int total = ObjectsTotal(0, 0, OBJ_LABEL) + ObjectsTotal(0, 0, OBJ_RECTANGLE_LABEL);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| NEW: Add this function - Handle chart events                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == prefix + "LeftArrow")
        {
         NavigateMonth(-1);
         ObjectSetInteger(0, prefix + "LeftArrow", OBJPROP_STATE, false);
        }
      else if(sparam == prefix + "RightArrow")
        {
         NavigateMonth(1);
         ObjectSetInteger(0, prefix + "RightArrow", OBJPROP_STATE, false);
        }
     }
  }

//+------------------------------------------------------------------+
//| NEW: Add this function - Navigate between months               |
//+------------------------------------------------------------------+
void NavigateMonth(int direction)
  {
   display_month += direction;
   
   if(display_month > 12)
     {
      display_month = 1;
      display_year++;
     }
   else if(display_month < 1)
     {
      display_month = 12;
      display_year--;
     }
   
   // Update current day highlighting
   datetime current = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(current, dt);
   
   if(display_month == dt.mon && display_year == dt.year)
      current_day = dt.day;
   else
      current_day = 0;
   
   // Recalculate month boundaries
   month_start = StringToTime(StringFormat("%04d.%02d.01", display_year, display_month));
   int next_month = display_month + 1, next_year = display_year;
   if(next_month > 12)
     {
      next_month = 1;
      next_year++;
     }
   month_end = StringToTime(StringFormat("%04d.%02d.01", next_year, next_month)) - 1;
   
   // Recreate calendar with new month/year
   CreateCalendar();
  }
  
  
  //+------------------------------------------------------------------+
//| NEW: Calculate actual weeks needed for the month                |
//+------------------------------------------------------------------+
int CalculateWeeksInMonth()
  {
   MqlDateTime dt;
   TimeToStruct(month_start, dt);
   
   int days_in_month = GetDaysInMonth(display_month, display_year);
   int first_day_of_week = dt.day_of_week;
   
   if(!ShowWeekends)
     {
      first_day_of_week = (first_day_of_week == 0) ? 4 : first_day_of_week - 1;
      if(first_day_of_week > 4)
         first_day_of_week = 0;
     }
   
   int total_cells_needed = first_day_of_week + days_in_month;
   int cols = ShowWeekends ? 7 : 5;
   
   return (int)MathCeil((double)total_cells_needed / cols);
  }