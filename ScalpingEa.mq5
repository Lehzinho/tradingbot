
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

input group "=== Trading Inputs ==="

input double            RiskPercent       = 3;                 // Risa as % of Trading Capital
input int               Tppoints          = 200;               // Take Profit (10 points = 1pip)
input int               Slpoints          = 200;               // Stoploss Point (10 points = 1pip)
input int               TslTriggerPoints  = 15;                // Points in profit before Trailing SL is activated (10 points = 1 pip)
input int               TslPoints         = 10;                // Traling Stop Loss (10 points = 1pip)
input ENUM_TIMEFRAMES   Timeframe         = PERIOD_CURRENT;    // Time frame to run
input int               InpMagic          = 29837;             // EA identification Num
input string            tradeComment      = "Scalping Robot";

enum StartHour                            { Inactive=0, _0100=1, _0200=2, _0300=3, _0400=4, _0500=5, _0600=6, _0700=7, _0800=8, _0900=9, _1000=10, _1100=11, _1200=12, _1300=13, _1400=14, _1500=15, _1600=16, _1700=17, _1800=18, _1900=19, _2000=20, _2100=21, _2200=22, _2300=23};

input StartHour         SHInput           = 0;

enum EndHour                              { Inactive=0, _0100=1, _0200=2, _0300=3, _0400=4, _0500=5, _0600=6, _0700=7, _0800=8, _0900=9, _1000=10, _1100=11, _1200=12, _1300=13, _1400=14, _1500=15, _1600=16, _1700=17, _1800=18, _1900=19, _2000=20, _2100=21, _2200=22, _2300=23};

input EndHour           EHInput           = 0;

int                     SHChoice;
int                     EHChoice;

int                     BarsN             = 5;
int                     ExpariationBars   = 100;
int                     OrderDisPoints    = 100;

CTrade         trade;
CPositionInfo  pos;
COrderInfo     ord;


int OnInit()
  {
  trade.SetExpertMagicNumber(InpMagic);
  ChartSetInteger(0, CHART_SHOW_GRID, false );
  return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {

   
  }

void OnTick()
  {
  
   TrailStop();
   if(!IsNewBar())return;
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(),time);
   
   int Hournow = time.hour;
   
   SHChoice = SHInput;
   EHChoice = EHInput;
   
   if(Hournow < SHChoice){CloseAllOrders(); return;}
   if(Hournow >= EHChoice && EHChoice != 0){CloseAllOrders(); return;}
   
int BuyTotal = 0;
int SellTotal = 0;

// Loop through all positions
for (int i = PositionsTotal() - 1; i >= 0; i--) {
    if (pos.SelectByIndex(i)) {  // Ensure the position is selected
        if (pos.PositionType() == POSITION_TYPE_BUY && pos.Symbol() == _Symbol && pos.Magic() == InpMagic)
            BuyTotal++;
        if (pos.PositionType() == POSITION_TYPE_SELL && pos.Symbol() == _Symbol && pos.Magic() == InpMagic)
            SellTotal++;
    }
}

// Loop through all orders
for (int i = OrdersTotal() - 1; i >= 0; i--) {
    if (ord.SelectByIndex(i)) {  // Ensure the order is selected
        if (ord.OrderType() == ORDER_TYPE_BUY_STOP && ord.Symbol() == _Symbol && ord.Magic() == InpMagic)
            BuyTotal++;
        if (ord.OrderType() == ORDER_TYPE_SELL_STOP && ord.Symbol() == _Symbol && ord.Magic() == InpMagic)
            SellTotal++;
    }
}



if (BuyTotal <= 0) {
    double hight = findHight();
    if (hight > 0) {
        SendBuyOrder(hight);
    }
}

if (SellTotal <= 0) {
    double low = findLow();
    if (low > 0) {
        SendSellOrder(low);  // This should be SendSellOrder, not SendBuyOrder
    }
}

  }
  
double findHight(){
   double highestHigh = 0;
   for(int i =0; i < 200; i++)
   {
      double high = iHigh(_Symbol,Timeframe,i);
      if(i > BarsN && iHighest(_Symbol,Timeframe,MODE_HIGH,BarsN*2+1, i-BarsN) == i)
      {
         if(high > highestHigh)
         {
            return high;
         }
      }
      highestHigh = MathMax(high, highestHigh);
   }
   return -1;
}

double findLow(){
   double lowestLow = DBL_MAX;
   for(int i =0; i < 200; i++)
   {
      double low = iLow(_Symbol,Timeframe,i);
      if(i > BarsN && iLowest(_Symbol,Timeframe,MODE_LOW,BarsN*2+1, i-BarsN) == i)
      {
         if(low < lowestLow)
         {
            return low;
         }
      }
      lowestLow = MathMin(low, lowestLow);
   }
   return -1;
}

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,Timeframe,0);
   if(previousTime!=currentTime){
      previousTime=currentTime;
      return true;
   }
   return false;

}

void SendBuyOrder(double entry){
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(ask > entry - OrderDisPoints * _Point) return;
   
   double tp = entry + Tppoints * _Point;
   
   double sl = entry - Slpoints * _Point;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(entry-sl);
   
   datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpariationBars * PeriodSeconds(Timeframe);
   
   trade.BuyStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
   
   
}

void SendSellOrder(double entry){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid < entry + OrderDisPoints * _Point) return;
   
   double tp = entry - Tppoints * _Point;
   
   double sl = entry + Slpoints * _Point;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(sl-entry);
   
   datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpariationBars * PeriodSeconds(Timeframe);
   
   trade.SellStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
   
   
}


double calcLots(double Slpoint) {
    double risk = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;

    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double volumeLimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

    double moneyPerLotStep = (Slpoint * tickValue) / tickSize;
    double lots = MathFloor(risk / moneyPerLotStep / lotStep) * lotStep;

    if (volumeLimit != 0) lots = MathMin(lots, volumeLimit);
    if (maxVolume != 0) lots = MathMin(lots, maxVolume);
    if (minVolume != 0) lots = MathMax(lots, minVolume);

    lots = NormalizeDouble(lots, 2);

    return lots;
}


void CloseAllOrders(){
   for(int i=OrdersTotal() -1; i>=0; i--)
   {
      ord.SelectByIndex(i);
      ulong ticket = ord.Ticket();
      if(ord.Symbol() == _Symbol && ord.Magic() == InpMagic)
      {
         trade.OrderDelete(ticket);
      }
   }
}

void TrailStop() {
    double sl = 0;
    double tp = 0;
    bool slChanged = false;
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--) {
        if (pos.SelectByIndex(i)) {
            ulong ticket = pos.Ticket();
            if (pos.Magic() == InpMagic && pos.Symbol() == _Symbol) {
                if (pos.PositionType() == POSITION_TYPE_BUY) {
                    double openPrice = pos.PriceOpen();
                    double triggerLevel = openPrice + TslTriggerPoints * _Point;
                    double moveLevel = triggerLevel + TslPoints * _Point;
                    double currentSl = pos.StopLoss();
                    // Check if price has reached the trigger level
                    if (bid >= triggerLevel) {
                        if (bid >= moveLevel) {
                            // Move stop loss to TslPoints above the order price
                            double newSlPrice = currentSl + TslTriggerPoints * _Point + TslPoints * _Point;
                            if(openPrice + 5 * _Point == currentSl){
                              slChanged = true;
                              sl = openPrice + 5 * _Point  + TslPoints * _Point;
                            }else if(bid >= newSlPrice){
                              slChanged = true;
                              sl = currentSl + TslPoints * _Point;
                            }
                        } else if(currentSl < openPrice){
                            slChanged = true;
                            // Set stop loss to the order price
                            sl = openPrice + 5 * _Point;
                        }
                        
                        tp = pos.TakeProfit();
                        
                        if (slChanged && sl + 5 * _Point > pos.StopLoss() || pos.StopLoss() == 0) {
                            trade.PositionModify(ticket, sl, tp);
                        }
                    }
                    
                } else if (pos.PositionType() == POSITION_TYPE_SELL) {
                    double openPrice = pos.PriceOpen();
                    double triggerLevel = openPrice - TslTriggerPoints * _Point;
                    double moveLevel = triggerLevel - TslPoints * _Point;
                    double currentSl = pos.StopLoss();                    
                    // Check if price has reached the trigger level
                    if (ask <= triggerLevel) {
                        if (ask <= moveLevel) {
                            // Move stop loss to TslPoints below the order price
                            double newSlPrice = currentSl -  TslTriggerPoints * _Point - TslPoints * _Point;
                            if(openPrice - 5 * _Point == currentSl){
                              slChanged = true;
                              sl = openPrice - 5 * _Point - TslPoints * _Point;
                            }else if(ask <= newSlPrice){
                              slChanged = true;
                              sl = currentSl - TslPoints * _Point;
                            }
                            
                        } else if(currentSl > openPrice){
                            slChanged = true;
                            // Set stop loss to the order price
                            sl = openPrice - 5 * _Point; 
                        }
                        
                        tp = pos.TakeProfit();
                        
                        if (slChanged  && sl - 5 * _Point < pos.StopLoss() || pos.StopLoss() == 0) {
                            trade.PositionModify(ticket, sl, tp);
                        }
                    }
                }
            }
        }
    }
}



  

