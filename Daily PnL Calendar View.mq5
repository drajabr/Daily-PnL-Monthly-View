//+------------------------------------------------------------------+
//|                              smaGUY_Daily_PnL_Calendar_View.mq5  |
//|                               Daily P&L Calendar View Indicator  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025 SmaGUY"
#property link      ""
#property version   "1.30"
#property description "Daily PnL on a monthly calendar view with enhanced features"
#property indicator_chart_window
#property indicator_plots 0

//--- Enums for user-friendly inputs
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

enum ENUM_CALENDAR_SIZE
  {
   SIZE_NORMAL = 0,       // Normal Size
   SIZE_COMPACT = 1,      // Compact Size
   SIZE_TINY = 2          // Tiny Size
  };

enum ENUM_YEAR_SELECTION
  {
   YEAR_2020 = 2020,     // 2020
   YEAR_2021 = 2021,     // 2021
   YEAR_2022 = 2022,     // 2022
   YEAR_2023 = 2023,     // 2023
   YEAR_2024 = 2024,     // 2024
   YEAR_2025 = 2025,     // 2025
   YEAR_2026 = 2026,     // 2026
   YEAR_2027 = 2027,     // 2027
   YEAR_2028 = 2028,     // 2028
   YEAR_2029 = 2029,     // 2029
   YEAR_2030 = 2030,     // 2030
   YEAR_CURRENT = 0      // Current Year
  };

enum ENUM_FONT_SELECTION
  {
   FONT_ARIAL = 0,       // Arial
   FONT_CALIBRI = 1,     // Calibri
   FONT_COURIER = 2,     // Courier
   FONT_COURIER_NEW = 3, // Courier New
   FONT_TAHOMA = 4,      // Tahoma
   FONT_VERDANA = 5      // Verdana
  };

enum ENUM_DRAW_MODE
  {
   DRAW_OVERLAY = 0,     // Draw as Overlay
   DRAW_BACKGROUND = 1   // Draw as Background
  };

//--- Input parameters
sinput string  s1 = "=== DISPLAY SETTINGS ===";        // ────────────────────
input int      FontSize = 8;                            // Font Size (Small for Profit Style)
input ENUM_FONT_SELECTION FontType = FONT_CALIBRI;     // Font Type
input ENUM_CALENDAR_POSITION CalendarPosition = POS_TOP_LEFT; // Calendar Position
input ENUM_CALENDAR_SIZE CalendarSize = SIZE_TINY;   // Calendar Size
input ENUM_DRAW_MODE DrawMode = DRAW_OVERLAY;           // Drawing Mode
input int      XDistance = 0;                          // Distance from Left/Right Edge
input int      YDistance = 0;                          // Distance from Top/Bottom Edge

sinput string  s2 = "=== TIME SETTINGS ===";           // ────────────────────
input ENUM_MONTH_SELECTION MonthToShow = MONTH_CURRENT; // Month to Display
input ENUM_YEAR_SELECTION YearToShow = YEAR_CURRENT;   // Year to Display

sinput string  s3 = "=== APPEARANCE SETTINGS ===";     // ────────────────────
input bool     ShowWeekends = false;                   // Show Weekend Days (Auto-adjusts width)
input bool     ShowCellBorders = false;                // Show Individual Cell Borders
input bool     ShowDates = false;                      // Show Date Numbers in Cells
input bool     HighlightCurrentDay = true;             // Highlight Current Day
input bool     IncludeOpenPnL = true;                  // Include Currently Open P&L

sinput string  s4 = "=== COLORS ===";                  // ────────────────────
input color    BackgroundColor = C'255,255,255';       // Background Color
input color    BorderColor = C'100,100,100';           // Main Border Color
input color    HeaderBackgroundColor = C'200,200,200'; // Header Background Color
input color    HeaderBorderColor = C'100,100,100';     // Header Border Color
input color    HeaderTextColor = clrBlack;             // Header Text Color
input color    DateTextColor = clrGray;                // Date Text Color
input color    ProfitTextColor = clrBlue;              // Profit Text Color
input color    LossTextColor = clrRed;                 // Loss Text Color
input color    BreakevenColor = clrGold;               // Breakeven Color
input color    CurrentDayColor = C'200,200,200';       // Current Day Background Color

sinput string  s5 = "=== ADVANCED SETTINGS ===";       // ────────────────────
input bool     ShowZeroDays = true;                    // Show Days with Zero P&L
input double   MinPnLToShow = 1;                       // Minimum P&L to Display
input int      DecimalPlaces = 0;                      // Decimal Places for P&L
input bool     ExcludeDepositsWithdrawals = true;      // Exclude Deposits/Withdrawals

//--- Global variables
string prefix = "PnL_Cal_";
int display_month, display_year;
double daily_pnl[];
datetime month_start, month_end;
int current_day = 0;
int calendar_columns = 7; // Auto-calculated based on ShowWeekends
double current_open_pnl = 0.0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Set auto width based on weekend setting
   calendar_columns = ShowWeekends ? 7 : 5;

//--- Set display period
   SetDisplayPeriod();

//--- Create calendar
   CreateCalendar();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteAllObjects();
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function - Updates on every tick     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
// Update calendar on every tick
   UpdateCalendar();

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Set display period based on inputs                              |
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

// Set month
   if(MonthToShow == MONTH_CURRENT)
      display_month = dt.mon;
   else
      display_month = (int)MonthToShow;

// Set year
   if(YearToShow == YEAR_CURRENT)
      display_year = dt.year;
   else
      display_year = (int)YearToShow;

// Calculate month boundaries
   month_start = StringToTime(StringFormat("%04d.%02d.01", display_year, display_month));

   int next_month = display_month + 1;
   int next_year = display_year;
   if(next_month > 12)
     {
      next_month = 1;
      next_year++;
     }
   month_end = StringToTime(StringFormat("%04d.%02d.01", next_year, next_month)) - 1;
  }

//+------------------------------------------------------------------+
//| Get calendar dimensions based on size setting                   |
//+------------------------------------------------------------------+
void GetCalendarDimensions(int &cell_width, int &cell_height, int &header_height, int &title_height)
  {
   switch(CalendarSize)
     {
      case SIZE_NORMAL:
         cell_width = 70;
         cell_height = 25;
         header_height = 25; // Same as cell height for seamless connection
         title_height = 40;
         break;
      case SIZE_COMPACT:
         cell_width = 50;
         cell_height = 18;
         header_height = 18; // Same as cell height for seamless connection
         title_height = 30;
         break;
      case SIZE_TINY:
         cell_width = 35;
         cell_height = 14;
         header_height = 14; // Same as cell height for seamless connection
         title_height = 22;
         break;
     }
  }

//+------------------------------------------------------------------+
//| Get font name based on selection                                |
//+------------------------------------------------------------------+
string GetFontName()
  {
   switch(FontType)
     {
      case FONT_CALIBRI:
         return "Calibri";
      case FONT_COURIER:
         return "Courier New";
      case FONT_COURIER_NEW:
         return "Courier New";
      case FONT_ARIAL:
         return "Arial";
      case FONT_TAHOMA:
         return "Tahoma";
      case FONT_VERDANA:
         return "Verdana";
      default:
         return "Calibri";
     }
  }

//+------------------------------------------------------------------+
//| Calculate current open P&L                                      |
//+------------------------------------------------------------------+
double CalculateOpenPnL()
  {
   double open_pnl = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != "")
        {
         if(PositionSelectByTicket(PositionGetTicket(symbol)))
           {
            open_pnl += PositionGetDouble(POSITION_PROFIT) +
                        PositionGetDouble(POSITION_SWAP);
           }
        }
     }

   return open_pnl;
  }

//+------------------------------------------------------------------+
//| Create perfect aligned table calendar                           |
//+------------------------------------------------------------------+
void CreateCalendar()
  {
   DeleteAllObjects();

   int CELL_WIDTH, CELL_HEIGHT, HEADER_HEIGHT, TITLE_HEIGHT;
   GetCalendarDimensions(CELL_WIDTH, CELL_HEIGHT, HEADER_HEIGHT, TITLE_HEIGHT);

   const int BORDER_WIDTH = 2;
   const int TABLE_WIDTH = CELL_WIDTH * calendar_columns;
   const int TABLE_HEIGHT = HEADER_HEIGHT + CELL_HEIGHT * 7; // No gap between header and table
   const int TOTAL_WIDTH = TABLE_WIDTH + (BORDER_WIDTH * 2);
   const int TOTAL_HEIGHT = TITLE_HEIGHT + TABLE_HEIGHT + (BORDER_WIDTH * 2);

// Calculate position
   int x, y;
   CalculatePosition(x, y, TOTAL_WIDTH, TOTAL_HEIGHT);

// Set Z-order based on draw mode
   int z_order = (DrawMode == DRAW_BACKGROUND) ? 0 : 1;

// Create main calendar background
   CreateRectangle(prefix + "MainBG", x, y, x + TOTAL_WIDTH, y + TOTAL_HEIGHT,
                   BackgroundColor, BorderColor, BORDER_WIDTH, z_order);

// Create title background
   CreateRectangle(prefix + "TitleBG", x + BORDER_WIDTH, y + BORDER_WIDTH,
                   x + TOTAL_WIDTH - BORDER_WIDTH, y + TITLE_HEIGHT,
                   HeaderBackgroundColor, HeaderBorderColor, 1, z_order);

// Create month/year header
   string month_names[] = {"", "January", "February", "March", "April", "May", "June",
                           "July", "August", "September", "October", "November", "December"
                          };
   string header_text = month_names[display_month] + " " + IntegerToString(display_year);

   int header_font_size = FontSize + (CalendarSize == SIZE_TINY ? 2 : 3);
   CreateLabel(prefix + "Header", header_text, x + TOTAL_WIDTH/2, y + TITLE_HEIGHT/2,
               header_font_size, HeaderTextColor, ANCHOR_CENTER, GetFontName(), z_order);

// Create day headers with perfect alignment (no gap)
   string day_names[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
   string business_days[] = {"Mon", "Tue", "Wed", "Thu", "Fri"};

   int table_start_x = x + BORDER_WIDTH;
   int table_start_y = y + TITLE_HEIGHT + BORDER_WIDTH; // No gap here

   for(int i = 0; i < calendar_columns; i++)
     {
      string day_name;
      if(ShowWeekends)
         day_name = day_names[i];
      else
         day_name = business_days[i];

      // Create day header background - seamlessly connected to table
      CreateRectangle(prefix + "DayHeaderBG_" + IntegerToString(i),
                      table_start_x + i * CELL_WIDTH, table_start_y,
                      table_start_x + (i + 1) * CELL_WIDTH, table_start_y + HEADER_HEIGHT,
                      HeaderBackgroundColor, ShowCellBorders ? HeaderBorderColor : clrNONE, 1, z_order);

      CreateLabel(prefix + "DayHeader_" + IntegerToString(i), day_name,
                  table_start_x + i * CELL_WIDTH + CELL_WIDTH/2, table_start_y + HEADER_HEIGHT/2,
                  FontSize, HeaderTextColor, ANCHOR_CENTER, GetFontName(), z_order);
     }

// Fill calendar with perfectly aligned dates
   FillCalendarDates(table_start_x, table_start_y + HEADER_HEIGHT, CELL_WIDTH, CELL_HEIGHT, z_order);
  }

//+------------------------------------------------------------------+
//| Fill calendar with dates and P&L data                           |
//+------------------------------------------------------------------+
void FillCalendarDates(int start_x, int start_y, int cell_width, int cell_height, int z_order)
  {
   MqlDateTime dt;
   TimeToStruct(month_start, dt);

   int days_in_month = GetDaysInMonth(display_month, display_year);
   int first_day_of_week = dt.day_of_week;

// Adjust first day for business days only
   if(!ShowWeekends)
     {
      first_day_of_week = (first_day_of_week == 0) ? 4 : first_day_of_week - 1; // Sunday = 4, Monday = 0
      if(first_day_of_week > 4)
         first_day_of_week = 0;
     }

// Create perfectly aligned date cells
   int day_counter = 1;
   for(int week = 0; week < 7; week++)
     {
      for(int day_col = 0; day_col < calendar_columns; day_col++)
        {
         int cell_x = start_x + day_col * cell_width;
         int cell_y = start_y + week * cell_height;

         // Determine if this cell should have a date
         bool should_show_date = false;
         if(week == 0 && day_col >= first_day_of_week)
            should_show_date = true;
         else
            if(week > 0 && day_counter <= days_in_month)
               should_show_date = true;

         if(should_show_date && day_counter <= days_in_month)
           {
            // Check if this is the current day
            bool is_current_day = (HighlightCurrentDay && day_counter == current_day);
            color bg_color = is_current_day ? CurrentDayColor : BackgroundColor;

            // Create cell background with perfect alignment
            color border_color = (ShowCellBorders || is_current_day) ? BorderColor : clrNONE;
            int border_width = (ShowCellBorders || is_current_day) ? 1 : 0;

            CreateRectangle(prefix + "Cell_" + IntegerToString(day_counter),
                            cell_x, cell_y, cell_x + cell_width, cell_y + cell_height,
                            bg_color, border_color, border_width, z_order);

            // Add date number if enabled
            if(ShowDates)
              {
               CreateLabel(prefix + "Date_" + IntegerToString(day_counter),
                           IntegerToString(day_counter),
                           cell_x + 3, cell_y + 2,
                           FontSize - 1, DateTextColor, ANCHOR_LEFT_UPPER, GetFontName(), z_order);
              }

            day_counter++;
           }
         else
           {
            // Create empty cell for perfect table alignment
            CreateRectangle(prefix + "EmptyCell_" + IntegerToString(week) + "_" + IntegerToString(day_col),
                            cell_x, cell_y, cell_x + cell_width, cell_y + cell_height,
                            BackgroundColor, ShowCellBorders ? BorderColor : clrNONE,
                            ShowCellBorders ? 1 : 0, z_order);
           }
        }

      if(day_counter > days_in_month)
         break;
     }
  }

//+------------------------------------------------------------------+
//| Update calendar with current P&L data                           |
//+------------------------------------------------------------------+
void UpdateCalendar()
  {
   CalculateDailyPnL();

// Get current open P&L if enabled
   if(IncludeOpenPnL)
      current_open_pnl = CalculateOpenPnL();

   int CELL_WIDTH, CELL_HEIGHT, HEADER_HEIGHT, TITLE_HEIGHT;
   GetCalendarDimensions(CELL_WIDTH, CELL_HEIGHT, HEADER_HEIGHT, TITLE_HEIGHT);

   const int BORDER_WIDTH = 2;
   const int TOTAL_WIDTH = CELL_WIDTH * calendar_columns + (BORDER_WIDTH * 2);
   const int TOTAL_HEIGHT = TITLE_HEIGHT + HEADER_HEIGHT + CELL_HEIGHT * 7 + (BORDER_WIDTH * 2);

   int x, y;
   CalculatePosition(x, y, TOTAL_WIDTH, TOTAL_HEIGHT);

   MqlDateTime dt;
   TimeToStruct(month_start, dt);
   int first_day_of_week = dt.day_of_week;
   int days_in_month = GetDaysInMonth(display_month, display_year);

// Adjust first day for business days only
   if(!ShowWeekends)
     {
      first_day_of_week = (first_day_of_week == 0) ? 4 : first_day_of_week - 1;
      if(first_day_of_week > 4)
         first_day_of_week = 0;
     }

   int table_start_x = x + BORDER_WIDTH;
   int table_start_y = y + TITLE_HEIGHT + BORDER_WIDTH + HEADER_HEIGHT;
   int z_order = (DrawMode == DRAW_BACKGROUND) ? 0 : 1;

// Update P&L labels
   int day_counter = 1;
   for(int week = 0; week < 7; week++)
     {
      for(int day_col = 0; day_col < calendar_columns; day_col++)
        {
         bool should_show_date = false;
         if(week == 0 && day_col >= first_day_of_week)
            should_show_date = true;
         else
            if(week > 0 && day_counter <= days_in_month)
               should_show_date = true;

         if(should_show_date && day_counter <= days_in_month && day_counter <= ArraySize(daily_pnl))
           {
            double pnl = daily_pnl[day_counter - 1];

            // Add current open P&L to today's total if enabled
            if(IncludeOpenPnL && day_counter == current_day)
               pnl += current_open_pnl;

            if(MathAbs(pnl) >= MinPnLToShow || ShowZeroDays)
              {
               string pnl_text = DoubleToString(pnl, DecimalPlaces);
               color text_color = (pnl > 0) ? ProfitTextColor :
                                  (pnl < 0) ? LossTextColor : BreakevenColor;

               int cell_x = table_start_x + day_col * CELL_WIDTH;
               int cell_y = table_start_y + week * CELL_HEIGHT;

               // Position PnL text based on whether dates are shown
               int text_y = ShowDates ? cell_y + CELL_HEIGHT - 3 : cell_y + CELL_HEIGHT/2;
               ENUM_ANCHOR_POINT anchor = ShowDates ? ANCHOR_LOWER : ANCHOR_CENTER;

               ObjectDelete(0, prefix + "PnL_" + IntegerToString(day_counter));
               CreateLabel(prefix + "PnL_" + IntegerToString(day_counter),
                           pnl_text,
                           cell_x + CELL_WIDTH/2, text_y,
                           FontSize, text_color, anchor, GetFontName(), z_order);
              }

            day_counter++;
           }
        }

      if(day_counter > days_in_month)
         break;
     }

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Calculate daily P&L from account history                        |
//+------------------------------------------------------------------+
void CalculateDailyPnL()
  {
   int days_in_month = GetDaysInMonth(display_month, display_year);
   ArrayResize(daily_pnl, days_in_month);
   ArrayInitialize(daily_pnl, 0.0);

// Request history for the month
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

      // Exclude deposits/withdrawals if setting is enabled
      if(ExcludeDepositsWithdrawals)
        {
         ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(deal_type == DEAL_TYPE_BALANCE)
            continue;
        }

      datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      MqlDateTime deal_dt;
      TimeToStruct(deal_time, deal_dt);

      if(deal_dt.year == display_year && deal_dt.mon == display_month)
        {
         int day_index = deal_dt.day - 1;
         if(day_index >= 0 && day_index < days_in_month)
           {
            daily_pnl[day_index] += profit + swap + commission;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate calendar position based on settings                   |
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
//| Create text label with Z-order support                          |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int font_size,
                 color clr, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER,
                 string font = "Calibri", int z_order = 1)
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
   ObjectSetInteger(0, name, OBJPROP_ZORDER, z_order);
  }

//+------------------------------------------------------------------+
//| Create rectangle with Z-order support                           |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x1, int y1, int x2, int y2,
                     color bg_color, color border_color = clrNONE, int border_width = 0, int z_order = 1)
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
   ObjectSetInteger(0, name, OBJPROP_ZORDER, z_order);
  }

//+------------------------------------------------------------------+
//| Get days in month                                               |
//+------------------------------------------------------------------+
int GetDaysInMonth(int month, int year)
  {
   int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

   if(month == 2 && IsLeapYear(year))
      return 29;

   return days[month - 1];
  }

//+------------------------------------------------------------------+
//| Check if year is leap year                                      |
//+------------------------------------------------------------------+
bool IsLeapYear(int year)
  {
   return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

//+------------------------------------------------------------------+
//| Delete all calendar objects                                     |
//+------------------------------------------------------------------+
void DeleteAllObjects()
  {
   int total = ObjectsTotal(0, 0, OBJ_LABEL) + ObjectsTotal(0, 0, OBJ_RECTANGLE_LABEL);

   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
        {
         ObjectDelete(0, name);
        }
     }

   ChartRedraw();
  }
