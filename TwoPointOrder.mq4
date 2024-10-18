 //+------------------------------------------------------------------+
//|                                                 CustomScript.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.github.com/yogeshswami-79/mq4.git"
#property version   "1.00"
#property strict


#define TIMER_INTERVAL 200


input int   TakeProfit=120; // Take Profit 2
input int TakeProfitDynamic=50; // Take Profit 1
input int   StopLoss=50;//Stop Loss

string g_lotSizeEditName = "LotSizeEdit";
double g_lotSize = 0.01; // Default lot size
double MIN_LOT_SIZE = 0.01;

struct OrderInfo {
   int ticket, magicNumber;
   double stopLoss, target, firstTarget;
   bool reachedFirstTP;
};

OrderInfo orderInfoArray[];



int getRandomMN() {
   return (int)TimeCurrent() + MathRand();
}

void updateOrderInfoArray() {
   int totalOrders = OrdersTotal();
   ArrayResize(orderInfoArray, totalOrders);
}

// Function to insert an order into the array
void insertOrder(OrderInfo &order) {
//   if(ArraySize(orderInfoArray) == 0) updateOrderInfoArray();
   int size = ArraySize(orderInfoArray);
   ArrayResize(orderInfoArray, size + 1);
   orderInfoArray[size] = order;
}

// Function to remove an order from the array
void removeOrder(int magicNumber) {
   int size = ArraySize(orderInfoArray);
   for(int i = 0; i < size; i++) {
       if(orderInfoArray[i].magicNumber == magicNumber) {
           for(int j = i; j < size - 1; j++) {
               orderInfoArray[j] = orderInfoArray[j + 1];
           }
           deleteLine(magicNumber);
           ArrayResize(orderInfoArray, size - 1);
           break;
       }
   }
}


void filterClosedOrders(){
   for(int i=0; i<ArraySize(orderInfoArray); i++){
      bool found= false;
      
      for(int j=0; j<OrdersTotal(); j++) {
         if( OrderSelect(i, SELECT_BY_POS, MODE_TRADES) ) 
            if( findOrderByMagicNumber(OrderMagicNumber()) > -1 )
               found = true;
      }  
      if(!found) removeOrder(orderInfoArray[i].magicNumber);
   }
}

void drawLine(int mn, double price){
   ObjectCreate(0, mn+"", OBJ_HLINE, 0, 0, price);
//---   ObjectCreate(0,"obj_name",OBJ_LABEL,0,0,0.75540);
   //---   ObjectCreate("Line",OBJ_VLINE,0,time,0,price);
}

void deleteLine(int mn) {
   ObjectDelete(0, mn+"");
}

int findOrderByMagicNumber(int magicNum) {
   for(int i=0; i<ArraySize(orderInfoArray); i++) 
      if(magicNum == orderInfoArray[i].magicNumber) return i;
   return -1;
}

void updateOrders() {
   for(int i=0; i<OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      updateOrderByMN( OrderMagicNumber(), OrderTicket(), OrderOpenPrice(), OrderStopLoss(), OrderType() );
   }
}

void updateOrderByMN(int magicNumber, int ticket, double openPrice, double currentSL, int orderType) {
   int idx = findOrderByMagicNumber(magicNumber);
   double sl = currentSL;
   if(idx == -1) return;
   if(orderInfoArray[idx].ticket != ticket) {
      orderInfoArray[idx].ticket = ticket;
      sl = orderInfoArray[idx].stopLoss;
   }
   if( !(orderType == OP_BUY || orderType == OP_SELL) || (currentSL == orderInfoArray[idx].stopLoss ) ) return;
   orderInfoArray[idx].stopLoss = sl;
   orderInfoArray[idx].firstTarget = openPrice + (openPrice - currentSL);
}

void readLotSize() {
    string text = ObjectGetString(0, g_lotSizeEditName, OBJPROP_TEXT);
    double newLotSize = StringToDouble(text);
    
    if(newLotSize >= MIN_LOT_SIZE) {
        g_lotSize = newLotSize;
    } else {
        g_lotSize = MIN_LOT_SIZE;
        Print("Lot size too small. Setting to minimum: ", MIN_LOT_SIZE);
    }
    
    // Update the edit box to reflect the actual lot size being used
    ObjectSetString(0, g_lotSizeEditName, OBJPROP_TEXT, DoubleToString(g_lotSize, 2));
}


// OnChartEvent function to handle button clicks
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   // Check if the event is a click on an object
   if(id == CHARTEVENT_OBJECT_CLICK) {
      // Check if the clicked object is our button
      if(sparam == "BUY")  placeBuyOrder();
      if(sparam == "SELL") placeSellOrder();

   }
}

void placeBuyOrder() {
   readLotSize();
   double lotSize = g_lotSize;
   double target = Ask + (Point * TakeProfit);
   double firstTarget = Ask + (Point * TakeProfitDynamic);
   double stopLoss = Ask - (Point * StopLoss);
   int magicNumber = getRandomMN();
   
   // Place the order
   int ticket=OrderSend(OrderSymbol(), OP_BUY, lotSize, Ask, 5, stopLoss, target, "", magicNumber, 0, clrGreen);
   
   if(ticket > 0) {
      OrderInfo newOrder;
      newOrder.ticket = ticket;
      newOrder.target = target;
      newOrder.firstTarget = firstTarget;
      newOrder.stopLoss = stopLoss;
      newOrder.magicNumber = magicNumber;
      newOrder.reachedFirstTP = false;
      insertOrder(newOrder);
      drawLine(magicNumber,newOrder.firstTarget);
      Print("Buy order placed successfully. Ticket: ", ticket);
   }
   else {
      Print("Error placing buy order. Error code: ", GetLastError());
   }
}

void placeSellOrder() {
   readLotSize();
   double lotSize = g_lotSize;
   double target = Bid - (Point * TakeProfit);
   double firstTarget = Bid - (Point * TakeProfitDynamic);
   double stopLoss = Bid + (Point * StopLoss);
   int magicNumber = getRandomMN();
   
   int ticket = OrderSend(OrderSymbol(), OP_SELL, lotSize, Bid, 5, stopLoss, target, "", magicNumber, 0, clrRed);
   if(ticket > 0) {
      OrderInfo newOrder;
      newOrder.ticket = ticket;
      newOrder.target = target;
      newOrder.firstTarget = firstTarget;
      newOrder.stopLoss = stopLoss;
      newOrder.magicNumber = magicNumber;
      newOrder.reachedFirstTP = false;
      insertOrder(newOrder);
      drawLine(magicNumber,newOrder.firstTarget);
      Print("Sell order placed successfully. Ticket: ", ticket);
   }
   else {
      Print("Error placing Sell order. Error code: ", GetLastError());
   }
}

void onBuyDebit(int i, double lots, double minLot){
   double lotToDebit = 0;
   double price = MarketInfo(OrderSymbol(), MODE_BID);

   Print("OnBuyDebit: --------------");
   Print("Lots: ", lots);
   Print("minLot: ", minLot);
   Print("price: ", price);
   Print("firstTarget: ", orderInfoArray[i].firstTarget);
   Print("reachedFirstTP: ", orderInfoArray[i].reachedFirstTP);

   if( (lots > minLot) && (price >= orderInfoArray[i].firstTarget) && !(orderInfoArray[i].reachedFirstTP) ) {
      orderInfoArray[i].reachedFirstTP = true;
      lotToDebit = NormalizeDouble(lots / 2, 2);
   }
         
   if(price >= orderInfoArray[i].target) 
      lotToDebit = OrderLots();

   if( ( lotToDebit > 0 && lotToDebit <= lots ) && partiallyCloseOrder(lotToDebit, price ) ) {
      orderInfoArray[i].reachedFirstTP = true;
      removeOrder(orderInfoArray[i].magicNumber);
      
   } else {
      if(lotToDebit > 0)
         Alert("Failed to Debit", lotToDebit);
      orderInfoArray[i].reachedFirstTP = false;
   }
}

void onSellDebit(int i, double lots, double minLot){
   double lotToDebit = 0;
   double price = MarketInfo(OrderSymbol(), MODE_ASK);
   if( (lots > minLot) && (price  <= orderInfoArray[i].firstTarget) && !(orderInfoArray[i].reachedFirstTP) ) {
      orderInfoArray[i].reachedFirstTP = true;
      lotToDebit = NormalizeDouble(lots / 2, 2);
   }
        
   if(price  <= orderInfoArray[i].target) 
      lotToDebit = OrderLots();

   if( ( lotToDebit > 0 && lotToDebit <= lots ) && partiallyCloseOrder(lotToDebit, price ) ) {
      orderInfoArray[i].reachedFirstTP = true;
      removeOrder(orderInfoArray[i].magicNumber);
   } else {
      if(lotToDebit > 0)
         Alert("Failed to Debit", lotToDebit);
      orderInfoArray[i].reachedFirstTP = false;
   }
}


bool partiallyCloseOrder(double lotsToDebit, double lastPrice) {
   Alert("Closing Order" , lastPrice);
   bool res = OrderClose( OrderTicket(), lotsToDebit , lastPrice, 5, clrGreen ) ;
   if(!res) {
      Alert("Failed To Close Order! retrying..: ", OrderTicket());
      return OrderClose( OrderTicket(), lotsToDebit , lastPrice, 5, clrGreen ) ;
   }
   return res;
}


void onPriceUpdateTick() {
   for(int i=0; i< ArraySize(orderInfoArray); i++) {
      if(!OrderSelect( orderInfoArray[i].ticket, SELECT_BY_TICKET, MODE_TRADES)) continue;
      double minLot = MarketInfo(Symbol(), MODE_MINLOT);
      double lots = OrderLots();
         
      if(OrderType() == OP_BUY) onBuyDebit(i, lots, minLot);
      else if (OrderType() == OP_SELL) onSellDebit(i, lots, minLot);
      else Alert("Couldn't Process OrderType:" , OrderTicket());
    }
}

// OnInit function
int OnInit() {
   // Create the button
   CreateButton("BUY", clrBlue);
   CreateButton("SELL", clrRed, 10);
   CreateLotSizeEdit();
   updateOrderInfoArray();
   if(!EventSetMillisecondTimer(TIMER_INTERVAL)) {
      Print("Failed to start the timer!");
      return INIT_FAILED;
   }
   return(INIT_SUCCEEDED);
}


// OnDeinit function
void OnDeinit(const int reason) {
   // Delete the button when the EA is removed
   ObjectDelete(0, "BUY");
   ObjectDelete(0, "SELL");
}

// Main program function
void OnTick() {
//   updateOrders();
   onPriceUpdateTick();
}


void OnTimer() {
   filterClosedOrders();
//   updateOrders();
}


// Function to create the lot size edit box on the chart
void CreateLotSizeEdit() {
    ObjectCreate(0, g_lotSizeEditName, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_XDISTANCE, 22);
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_YDISTANCE, 20);
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_XSIZE, 80);
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_YSIZE, 15);
    ObjectSetString(0, g_lotSizeEditName, OBJPROP_TEXT, DoubleToString(g_lotSize, 2));
    ObjectSetString(0, g_lotSizeEditName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, g_lotSizeEditName, OBJPROP_BORDER_COLOR, clrGray);
}

// Create the button
void CreateButton(string buttonName, color btn_clr, int posXGap=0) {
   // Define button coordinates and size
   int width = 100;
   int height = 30;
   int x = posXGap > 0 ? 20 + width + posXGap: 20;
   int y = 40;

   // Create the button object
   if(!ObjectCreate(0, buttonName, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Failed to create the button object");
      return;
   }

   // Set button properties
   ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, buttonName, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, buttonName, OBJPROP_YSIZE, height);
   ObjectSetString(0, buttonName, OBJPROP_TEXT, buttonName);
   ObjectSetInteger(0, buttonName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, btn_clr);
   ObjectSetInteger(0, buttonName, OBJPROP_BORDER_COLOR, clrBlack);
}

