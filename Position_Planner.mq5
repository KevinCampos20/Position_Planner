//+------------------------------------------------------------------+
//|                                              PositionPlanner.mq5 |
//|                                  Copyright 2026, Position Planner|
//|                                          https://www.mql5.com/es |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Position Planner"
#property link      "https://www.mql5.com/es"
#property version   "1.03"
#property description "Planificador visual y gestor de posiciones arrastrables,"
#property description "lotaje configurable, ejecución de mercado o pendiente, parciales,"
#property description "break-even neto de costes, trailing y límites de cuenta."
#property description "EA mono-símbolo: opera únicamente sobre el símbolo del gráfico."
#property description "Pruebe siempre en cuenta demo antes de operar con capital real."

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| CODIGOS DE ERROR DE ARCHIVO (no declarados nativamente en MQL5) |
//+------------------------------------------------------------------+
#ifndef ERR_FILE_ACCESS_DENIED
   #define ERR_FILE_ACCESS_DENIED 5004
#endif

//+------------------------------------------------------------------+
//| CONSTANTES - TIPOGRAFÍA E ICONOGRAFÍA                            |
//+------------------------------------------------------------------+

#define ICON_FONT            "Segoe UI Symbol"
#define PANEL_FONT           "Segoe UI"
#define PANEL_FONT_BOLD      "Segoe UI Semibold"

#define ICON_CHAR_LOCKED     "●"
#define ICON_CHAR_FREE       "○"
#define ICON_CHAR_EXECUTED   "◆"
#define ICON_CHAR_PENDING    "▲"
#define ICON_CHAR_CLOSED     "×"
#define ICON_CHAR_DEGENERATE "!"
#define ICON_CHAR_NONE       "–"
#define ICON_CHAR_GEAR       "⚙"
#define ICON_CHAR_CHECK      "✓"

//+------------------------------------------------------------------+
//| CONSTANTES - IDENTIDAD E INSTANCIA                               |
//+------------------------------------------------------------------+
#define INSTANCE_HB_PERIOD_MS 5000
#define INSTANCE_LOCK_RETRY_MS 45000
#define DESTRUCTIVE_CONFIRM_WINDOW_MS 4000
#define ZONE_VOLUME_RECALC_THROTTLE_MS 220
#define LIMITS_CHECK_MS 1000
#define INSTANCE_HB_STALE_SEC 30
#define OBJECT_NAME_MAX_LEN   63
#define TOOLTIP_MAX_LEN       127

#define ORDER_COMMENT_MAX_LEN 26

const string APP_NAME    = "PositionPlanner";
const string APP_VERSION = "1.03"; // sincronizado con #property version

//+------------------------------------------------------------------+
//| CONSTANTES - ENTRADA (RATÓN Y TECLADO)                           |
//+------------------------------------------------------------------+
const int MOUSE_LEFT_BUTTON = 1;
const int KEY_DELETE        = 46;

const int MOUSE_CLICK_THRESHOLD       = 6;
const int MOUSE_CLICK_THRESHOLD_ENTRY = 10;
const int MOUSE_DRAG_THRESHOLD_PX     = 3;
const int HOVER_THROTTLE_MS           = 30;

const int LABEL_HIT_WIDTH_PX  = 90;
const int LABEL_HIT_HEIGHT_PX = 10;

const int DRAG_REDRAW_THROTTLE_MS     = 16;

const int DELETE_KEY_BLIND_MS = 2000;
const int EDIT_OVERWRITE_GUARD_MS = 400;
const int MAX_AUTO_TEMPLATE_FAILURES = 3;

//+------------------------------------------------------------------+
//| CONSTANTES - GEOMETRÍA DEL PANEL                                 |
//+------------------------------------------------------------------+
#define PANEL_ZORDER_BOOST 100000

const int PANEL_HANDLE_HEIGHT  = 40;
const int PANEL_HEIGHT         = 590;
const int PANEL_MARGIN         = 12;
const int PANEL_BUTTON_GAP     = 12;
const int PANEL_PADLOCK_SIZE   = 34;
const int PANEL_EDIT_WIDTH     = 84;
const int PANEL_EDIT_HEIGHT    = 30;
const int PANEL_BUTTON1_HEIGHT = 44;
const int PANEL_BUTTON2_HEIGHT = 34;
const int PANEL_BUTTON3_HEIGHT = 32;
const int PANEL_GEAR_SIZE      = 34;

const int PANEL_ROW2_Y   = 61;
const int PANEL_SEP1_Y   = 113;
const int PANEL_SEC1_Y   = 121;
const int PANEL_LOTAJE_Y = 137;

const int PANEL_SEP2_Y   = 175;
const int PANEL_ROW3_Y   = 183;

const int PANEL_ROW4_Y   = 235;
const int PANEL_ROW5_Y   = 277;

const int PANEL_SEP3_Y       = 317;
const int PANEL_MGMT_HDR_Y   = 325;
const int PANEL_MGMT_ROW_Y   = 349;
const int PANEL_MGMT_ROW_H   = 28;

const int PANEL_SEP4_Y       = 385;
const int PANEL_TP_HEADER_Y  = 393;
const int PANEL_TP_ROW0_Y    = 417;
const int PANEL_TP_ROW_STEP  = 30;
const int PANEL_TP_EDIT_H    = 22;
const int PANEL_TP_LABEL_W   = 32;
const int PANEL_TP_UNIT_W    = 12;
const int PANEL_TP_CHK_SIZE  = 16;
const int PANEL_TP_CHK_W     = 24;
const int PANEL_TP_BLOCK_GAP = 12;
const int PANEL_TP_COL_INDENT = 30;

const int PANEL_SEP5_Y        = 507;
const int PANEL_STATUS_BG_Y   = 515;
const int PANEL_STATUS_BG_H   = 67;
const int PANEL_STATUS_Y      = 523;
const int PANEL_STATUS_LINE_H = 17;
const int PANEL_STATUS_PAD_X  = 10;

const int PANEL_MIN_WIDTH = 360;

const int PANEL_LABEL_HIDE_MARGIN_PX = 3;

const int STATS_LABEL_GAP_PX = 6;

//+------------------------------------------------------------------+
//| CONSTANTES - PANEL DE CONFIGURACIÓN                              |
//+------------------------------------------------------------------+
#define SETTINGS_FIELDS 22

const int SETTINGS_WIDTH    = 360;
const int SETTINGS_HEADER_H = 40;
const int SETTINGS_ROW_H    = 26;
const int SETTINGS_ROW_STEP = 30;
const int SETTINGS_EDIT_W   = 70;
const int SETTINGS_HINT_W   = 62;
const int SETTINGS_HINT_GAP = 8;
const int SETTINGS_MARGIN   = 12;
const int SETTINGS_FOOTER_H = 34;

//+------------------------------------------------------------------+
//| CONSTANTES - EJECUCIÓN, GESTIÓN Y PERSISTENCIA                   |
//+------------------------------------------------------------------+
#define QUOTE_MAX_AGE_MS 5000
#define PARTIAL_STAGES   3

#define INITIAL_POSITIONS_CAPACITY 20
#define INITIAL_MANAGEMENT_CAPACITY 10
#define INITIAL_PANEL_OBJECTS_CAPACITY 100

const int MAX_BACKOFF_MS         = 10000;
const int MAX_BACKOFF_SHIFT      = 16;
// Nota: el timeout de envío debe ser mayor que AMBIGUOUS_SEND_WAIT_MS +
// UNCERTAIN_PROBE_MAX_DELAY_MS; en caso contrario el plan se aborta antes de
// que la sonda de reconciliación pueda ejecutarse (quedaría huérfana).
const int ORDER_LOCK_TIMEOUT     = 25000;
// Ventana mínima tras un fallo "ambiguo" de mercado (timeout/conexión): el
// primer reintento DEBE esperar a que la posición aparezca en la cuenta para
// no abrir una segunda operación si el primer envío sí llegó al servidor.
const int AMBIGUOUS_SEND_WAIT_MS = 8000;
// Sondas adicionales (con backoff) antes de abandonar un envío ambiguo.
const int UNCERTAIN_PROBE_MAX    = 3;
const int UNCERTAIN_PROBE_BASE_MS= 4000;
const int UNCERTAIN_PROBE_MAX_DELAY_MS = 15000;
const int FLATTEN_MAX_PASSES     = 5;
const int FLATTEN_RETRY_MS       = 2000;
const int FLATTEN_SLOW_RETRY_MS  = 30000;
const int FLATTEN_ALERT_EVERY    = 10;
const int CANCEL_MAX_ATTEMPTS    = 3;
const int PROPAGATE_CHECK_MS     = 2000;
const int NATIVE_LEVELS_CHECK_MS = 2000;
const int PENDING_FILL_TIMEOUT_MS = 30000;
const int STATE_FLUSH_MS         = 1000;
const int ADOPT_CHECK_MS         = 5000;
const int CHART_CHANGE_THROTTLE_MS = 120;

const int PANEL_FAST_REFRESH_MS = 100;
const int PANEL_SLOW_REFRESH_MS = 500;

const int LEVELS_CHECK_MS = 1500;

const string STATE_HEADER_V5 = "PPLN_STATE_V5";
const string STATE_HEADER_V6 = "PPLN_STATE_V6";
const string STATE_HEADER_V7 = "PPLN_STATE_V7";
const string STATE_HEADER_V8 = "PPLN_STATE_V8"; // + línea L: baselines de límites diario/semanal persistidos
const string CFG_HEADER_V2   = "PPLN_CFG_V2";
const string CFG_HEADER_V3   = "PPLN_CFG_V3";
const string LOCK_HEADER_V1  = "PPLN_LOCK_V1";
// C-3: dos fases en el lock de instancia — CLAIM (reclamación provisional del
// handshake) y HEARTBEAT (primaria confirmada). La segunda línea del archivo
// es siempre "state=<FASE>" para que los lectores distingan ambos casos.
const string LOCK_STATE_CLAIM     = "CLAIM";
const string LOCK_STATE_HEARTBEAT = "HEARTBEAT";

#define CFG_MAX_KEYS 256

//+------------------------------------------------------------------+
//| ENUMERACIONES                                                    |
//+------------------------------------------------------------------+
enum ENUM_PLANNER_POS_TYPE
{
   PLANNER_POS_BUY  = 0,
   PLANNER_POS_SELL = 1
};

enum ENUM_VOLUME_MODE
{
   VOL_FIXED        = 0,
   VOL_RISK_PERCENT = 1
};

enum ENUM_EXEC_MODE
{
   EXEC_STRICT      = 0,
   EXEC_PENDING     = 1,
   EXEC_MARKET_ONLY = 2
};

enum ENUM_TRAILING_METHOD
{
   TRAIL_NONE  = 0,
   TRAIL_FIXED = 1,
   TRAIL_ATR   = 2
};

enum ENUM_LIMIT_BASE
{
   LIMIT_EQUITY  = 0,
   LIMIT_BALANCE = 1
};

enum ENUM_RISK_BASE
{
   RISK_MIN     = 0,
   RISK_EQUITY  = 1,
   RISK_BALANCE = 2
};

enum ENUM_BE_TRIGGER
{
   BE_AFTER_PARTIAL1 = 1,
   BE_AFTER_PARTIAL2 = 2,
   BE_AFTER_PARTIAL3 = 3
};

enum ENUM_DRAG_MODE
{
   DRAG_NONE = 0,
   DRAG_ENTRY_LINE,
   DRAG_TP_LINE,
   DRAG_SL_LINE,
   DRAG_PARTIAL_LINE,
   DRAG_ENTIRE_ZONE,
   DRAG_LEFT_BORDER,
   DRAG_RIGHT_BORDER,
   DRAG_ENTRY_LEFT,
   DRAG_ENTRY_RIGHT
};

enum ENUM_LIMIT_SCOPE
{
   LIMIT_SCOPE_NONE   = 0,
   LIMIT_SCOPE_DAILY  = 1,
   LIMIT_SCOPE_WEEKLY = 2
};

//+------------------------------------------------------------------+
//| PARÁMETROS DE ENTRADA                                            |
//+------------------------------------------------------------------+
input group "Volumen y Riesgo"
input ENUM_VOLUME_MODE InpVolumeMode_Default  = VOL_FIXED;
input double           InpFixedVolume_Default = 0.01;
input double           InpRiskPercent_Default = 1.0;
input ENUM_RISK_BASE   InpRiskBase_Default    = RISK_MIN;
input double           InpRiskCommissionPerLot_Default = 0.0;

input group "Niveles y Posiciones"
input int InpDefaultTPTicks_Default = 200;
input int InpDefaultSLTicks_Default = 100;
input int InpZoneWidthBars_Default  = 10;
input int InpMaxClosedZones_Default = 20;

input group "Estilo Visual"
input color InpColorTP_Default          = C'22,178,133';
input color InpColorSL_Default          = C'236,72,88';
input color InpColorEntry_Default       = C'150,157,171';
input color InpColorStats_Default       = C'237,240,246';
// Nota: el valor por defecto se limita a 92 en tiempo de ejecución para que
// el relleno de las zonas quede siempre semitransparente (máx. 8% de opacidad)
// y no oculte las velas. El usuario puede subirlo manualmente hasta 100.
input int   InpZoneTransparency_Default = 92;
input int   InpFontSizeStats_Default    = 8;
input int   InpLineWidth_Default        = 1;
input bool  InpShowLevels_Default       = true;
input bool  InpShowPnL_Default          = true;

input group "Ejecución de Órdenes"
input int            InpMagicNumber_Default     = 20260712;
input ENUM_EXEC_MODE InpExecMode_Default        = EXEC_STRICT;
input double         InpEntryToleranceTicks_Default = 5.0;
input int            InpPendingExpiryMinutes_Default = 0;
input int            InpMaxDeviation_Default    = 10;
input int            InpMaxRetries_Default      = 5;
input int            InpBackoffBase_Default     = 250;
input double         InpMaxVolDeviationPct_Default = 5.0;
input bool           InpKeepDistancesOnFillShift_Default = true;

input group "Gestión Automática"
input int    InpManagementInterval_Default = 2;
input bool   InpEnablePartials_Default     = false;
input double InpPartial1Multiple_Default   = 40.0;
input double InpPartial1Percent_Default    = 40.0;
input double InpPartial2Multiple_Default   = 70.0;
input double InpPartial2Percent_Default    = 30.0;
input double InpPartial3Multiple_Default   = 100.0;
input double InpPartial3Percent_Default    = 30.0;

input bool            InpEnableBreakEven_Default      = false;
input ENUM_BE_TRIGGER InpBreakEvenTrigger_Default     = BE_AFTER_PARTIAL1;
input double          InpBreakEvenStartR_Default      = 1.0;
input int             InpBreakEvenOffsetTicks_Default = 5;
input bool            InpBreakEvenCoverCosts_Default  = true;

input bool                 InpEnableTrailing_Default        = false;
input double               InpTrailingStartR_Default        = 1.0;
input int                  InpTrailingStepTicks_Default     = 10;
input ENUM_TRAILING_METHOD InpTrailingMethod_Default        = TRAIL_FIXED;
input int                  InpTrailingTicks_Default         = 150;
input ENUM_TIMEFRAMES      InpTrailingATRTimeframe_Default  = PERIOD_CURRENT;
input int                  InpTrailingATRPeriod_Default     = 14;
input double               InpTrailingATRMultiplier_Default = 2.0;

input group "Protección de Niveles"
input bool InpVerifyProtectiveLevels_Default = true;
input int  InpMaxLevelRetries_Default        = 5;
input bool InpEmergencyCloseIfNoSL_Default   = true;

input group "Reintentos y Adopción"
input int  InpManagementRetryBackoffSec_Default = 15;
input int  InpManagementMaxFailures_Default     = 20;
input bool InpAdoptOrphanPositions_Default      = true;

input group "Cuentas Netting"
input bool InpAllowNettingTrading_Default    = false;
input bool InpAllowNettingManagement_Default = false;

input group "Notificaciones"
input bool InpEnablePushNotifications_Default = false;

input group "Límites de Cuenta"
input int             InpMaxOpenPositions_Default  = 0;   // 0 = sin límite; máx. posiciones simultáneas del EA
input double          InpDailyLossLimit_Default    = 0.0;
input double          InpWeeklyLossLimit_Default   = 0.0;
input ENUM_LIMIT_BASE InpLimitBase_Default         = LIMIT_EQUITY;
input bool            InpCloseOnLimit_Default      = true;
input double          InpLimitWarningLevel_Default = 80.0;
input bool            InpLimitIgnoreBalanceOps_Default = true;
input int             InpLimitResetHour_Default    = 0;

input group "Panel y Configuración"
input double InpPanelZoom_Default              = 1.0;
input int    InpPanelWidth_Default             = 420;
input string InpObjectPrefix_Default           = "PPLN";
input bool   InpHideNativeTradeLevels_Default  = true;
input bool   InpEnableAutoTemplate_Default     = false;

input group "Instancia y Persistencia"
input string InpInstanceTag_Default     = "";
input bool   InpLoadSavedConfig_Default = true;
input bool   InpClearStateOnRemove      = false;
input bool   InpForceResetStateNow      = false;
input bool   InpForcePrimaryOnLockFailure_Default = false;
input bool   InpStrictInstanceLock_Default        = true; // 1er reintento de lock exige heartbeat ausente/antiguo

//+------------------------------------------------------------------+
//| VALORES EN VIVO                                                  |
//+------------------------------------------------------------------+
ENUM_VOLUME_MODE InpVolumeMode;
double InpFixedVolume;
double InpRiskPercent;
ENUM_RISK_BASE InpRiskBase;
double InpRiskCommissionPerLot;
int InpDefaultTPTicks;
int InpDefaultSLTicks;
int InpZoneWidthBars;
int InpMaxClosedZones;
color InpColorTP;
color InpColorSL;
color InpColorEntry;
color InpColorStats;
int InpZoneTransparency;
int InpFontSizeStats;
int InpLineWidth;
bool InpShowLevels;
bool InpShowPnL;
int InpMagicNumber;
ENUM_EXEC_MODE InpExecMode;
double InpEntryToleranceTicks;
int InpPendingExpiryMinutes;
int InpMaxDeviation;
int InpMaxRetries;
int InpBackoffBase;
double InpMaxVolDeviationPct;
bool InpKeepDistancesOnFillShift;
int InpManagementInterval;
bool InpEnablePartials;
double InpPartial1Multiple;
double InpPartial1Percent;
double InpPartial2Multiple;
double InpPartial2Percent;
double InpPartial3Multiple;
double InpPartial3Percent;
bool InpEnableBreakEven;
ENUM_BE_TRIGGER InpBreakEvenTrigger;
double InpBreakEvenStartR;
int InpBreakEvenOffsetTicks;
bool InpBreakEvenCoverCosts;
bool InpEnableTrailing;
double InpTrailingStartR;
int InpTrailingStepTicks;
ENUM_TRAILING_METHOD InpTrailingMethod;
int InpTrailingTicks;
ENUM_TIMEFRAMES InpTrailingATRTimeframe;
int InpTrailingATRPeriod;
double InpTrailingATRMultiplier;
bool InpVerifyProtectiveLevels;
int InpMaxLevelRetries;
bool InpEmergencyCloseIfNoSL;
int InpManagementRetryBackoffSec;
int InpManagementMaxFailures;
bool InpAdoptOrphanPositions;
bool InpAllowNettingTrading;
bool InpAllowNettingManagement;
bool InpEnablePushNotifications;
double g_daily_loss_limit;
double g_weekly_loss_limit;
ENUM_LIMIT_BASE InpLimitBase;
bool InpCloseOnLimit;
double InpLimitWarningLevel;
bool InpLimitIgnoreBalanceOps;
int InpLimitResetHour;
double InpPanelZoom;
int InpPanelWidth;
string InpObjectPrefix;
bool InpHideNativeTradeLevels;
bool InpEnableAutoTemplate;
string InpInstanceTag;
bool InpLoadSavedConfig;
bool InpForcePrimaryOnLockFailure;
bool InpStrictInstanceLock;
int  InpMaxOpenPositions;

//+------------------------------------------------------------------+
//| ESTRUCTURAS DE DATOS                                             |
//+------------------------------------------------------------------+
struct SVisualPosition
{
   long                  id;
   string                symbol;
   ENUM_PLANNER_POS_TYPE type;
   double                entry_price;
   double                tp_price;
   double                sl_price;
   datetime              time_start;
   datetime              time_end;
   datetime              closed_at;
   double                qty;
   bool                  qty_valid;
   bool                  is_locked;
   bool                  use_ask_anchor;
   bool                  is_degenerate;
   bool                  is_executed;
   bool                  is_closed;
   ulong                 ticket;
   ulong                 order_ticket;
   bool                  partial_is_manual[PARTIAL_STAGES];
   double                partial_manual_price[PARTIAL_STAGES];
};

struct SPositionManagement
{
   ulong  ticket;
   long   order_type;
   double volume_original;
   double entry_price;
   double risk_distance;
   double target_distance;

   bool   plan_partials_on;
   bool   plan_stage_active[PARTIAL_STAGES];
   double plan_stage_price[PARTIAL_STAGES];
   double plan_stage_pct[PARTIAL_STAGES];

   bool   plan_be_on;
   int    plan_be_stage;
   int    plan_be_offset_ticks;
   double plan_be_start_r;
   bool   plan_be_cover_costs;

   bool   plan_trail_on;
   int    plan_trail_method;
   int    plan_trail_ticks;
   int    plan_trail_step_ticks;
   double plan_trail_start_r;
   double plan_trail_atr_mult;

   bool   partial_resolved[PARTIAL_STAGES];
   bool   partial_executed[PARTIAL_STAGES];
   double partial_executed_volume[PARTIAL_STAGES];
   bool   partial_skipped_warned[PARTIAL_STAGES];
   int    partial_fail_count[PARTIAL_STAGES];

   bool   breakeven_done;
   bool   trailing_active;
   bool   foreign_warned;
   bool   be_orphan_warned; // A3/#6: aviso único de BE huérfano por parcial desactivado

   double intended_sl;
   double intended_tp;
   bool   levels_pending;
   int    level_attempts;
   bool   level_alerted;
   int    emergency_close_fail_count;

   ulong  next_attempt_ms;
   int    fail_count;
   bool   failure_reported;
};

struct SOrderPlan
{
   bool            active;
   bool            is_pending;
   ENUM_ORDER_TYPE type;
   double          volume;
   double          price;
   double          sl;
   double          tp;
   string          comment;
   long            zone_id;
   datetime        expiration;
};

struct SSearchCache
{
   long  last_position_id;
   int   last_position_result;
   ulong last_mgmt_ticket;
   int   last_mgmt_result;

   void Reset()
   {
      last_position_id = -1;
      last_position_result = -1;
      last_mgmt_ticket = 0;
      last_mgmt_result = -1;
   }
};

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
SVisualPosition g_positions[];
long            g_position_counter = 0;
long            g_selected_id      = -1;
long            g_hover_id         = -1;

SSearchCache g_search_cache;

double g_volume          = 0.01;
int    g_tp_ticks        = 200;
int    g_sl_ticks        = 100;
int    g_zone_width_bars = 20;
int    g_transparency    = 80;
bool   g_show_levels     = true;
bool   g_show_pnl        = true;
int    g_font_size_stats = 8;
int    g_line_width      = 1;
int    g_closed_zone_limit = 20;

bool g_enable_partials  = false;
bool g_enable_breakeven = false;
bool g_enable_trailing  = false;

bool g_mgmt_allowed       = true;
bool g_exec_allowed       = true;
bool g_degraded_mode      = false;
string g_degraded_reason  = "";

double g_partial_mult[PARTIAL_STAGES];
double g_partial_pct[PARTIAL_STAGES];
bool   g_partial_enabled[PARTIAL_STAGES];

int    g_be_offset_ticks         = 5;
double g_be_start_r              = 1.0;
int    g_trailing_ticks          = 150;
int    g_trailing_step_ticks     = 10;
int    g_trailing_atr_period     = 14;
double g_trailing_atr_multiplier = 2.0;
double g_trailing_start_r        = 1.0;

ENUM_TIMEFRAMES g_trail_atr_tf     = PERIOD_H1;
bool            g_trail_atr_failed = false;

int g_management_interval = 2;
int g_mgmt_backoff_sec    = 15;
int g_mgmt_max_failures   = 20;

int    g_max_deviation         = 10;
int    g_max_retries           = 5;
int    g_backoff_base          = 250;
double g_max_vol_dev_pct       = 5.0;
double g_entry_tolerance_ticks = 5.0;
double g_limit_warning_ratio   = 0.8;

double g_panel_zoom  = 1.0;
int    g_panel_width = 340;

double g_effective_risk_percent = -1.0;

CTrade              g_trade_object;
SPositionManagement g_management[];
int                 g_atr_handle_trailing = INVALID_HANDLE;

SOrderPlan g_plan;
bool       g_order_retry_active = false;
int        g_order_retry_count  = 0;
ulong      g_order_retry_time   = 0;
ulong      g_order_lock_time    = 0;
datetime   g_order_attempt_time = 0;
bool       g_send_uncertain     = false; // un envío de mercado pudo haber llegado al servidor sin confirmación
int        g_uncertain_probes   = 0;     // sondas de reconciliación extra ya realizadas

long   g_pending_fill_zone_id = -1;
ulong  g_pending_fill_order   = 0;
ulong  g_pending_fill_ms      = 0;

double           g_balance_day_start   = 0.0;
double           g_balance_week_start  = 0.0;
datetime         g_date_day_start      = 0;
datetime         g_date_week_start     = 0;
bool             g_limit_baseline_restored = false; // baselines recuperados del state file en este arranque
bool             g_is_limit_locked     = false;
string           g_limit_lock_reason   = "";
ENUM_LIMIT_SCOPE g_limit_lock_scope    = LIMIT_SCOPE_NONE;
bool             g_daily_warning_sent  = false;
bool             g_weekly_warning_sent = false;

bool   g_flatten_pending  = false;
int    g_flatten_attempts = 0;
string g_flatten_reason   = "";
ulong  g_flatten_next_ms  = 0;

bool           g_needs_redraw    = false;
ENUM_DRAG_MODE g_drag_mode       = DRAG_NONE;
long           g_drag_id         = -1;
double         g_drag_ref_price  = 0.0;
datetime       g_drag_ref_time   = 0;
double         g_drag_snap_entry = 0.0;
double         g_drag_snap_tp    = 0.0;
double         g_drag_snap_sl    = 0.0;
datetime       g_drag_snap_t1    = 0;
datetime       g_drag_snap_t2    = 0;
int            g_drag_stage      = -1;
bool           g_drag_warned     = false;
double         g_drag_snap_partial_stage[PARTIAL_STAGES];

bool g_chart_change_pending = false;

double g_price_per_pixel       = 0.0;
bool   g_price_per_pixel_dirty = true;

int  g_panel_x             = 16;
int  g_panel_y             = 46;
bool g_panel_dragging      = false;
bool g_panel_layout_pending = false;
bool g_settings_layout_pending = false;
int  g_panel_drag_offset_x = 0;
int  g_panel_drag_offset_y = 0;

bool g_left_button_was_down = false;
int  g_mouse_down_px        = 0;
int  g_mouse_down_py        = 0;
bool g_drag_start_pending   = false;

bool   g_panel_built          = false;
bool   g_panel_dirty          = true;
string g_panel_status_text    = "";
bool   g_panel_status_problem = false;
ulong  g_panel_status_set_ms  = 0;

string g_panel_obj_names[];
int    g_panel_obj_rel_x[];
int    g_panel_obj_rel_y[];
int    g_panel_obj_count      = 0;
string g_settings_obj_names[];
int    g_settings_obj_rel_x[];
int    g_settings_obj_rel_y[];
int    g_settings_obj_count   = 0;

int  g_suppress_object_events = 0;
bool g_pending_panel_rebuild  = false;
bool g_pending_zone_rebuild   = false;

ulong g_last_edit_ms = 0;
bool  g_edit_focus_active = false;

bool   g_settings_panel_open    = false;
bool   g_settings_panel_built   = false;
string g_settings_edit_error    = "";
int    g_settings_x             = 20;
int    g_settings_y             = 20;
bool   g_settings_dragging      = false;
int    g_settings_drag_offset_x = 0;
int    g_settings_drag_offset_y = 0;

string g_settings_labels[SETTINGS_FIELDS];
string g_settings_hints[SETTINGS_FIELDS];

bool g_chart_settings_saved   = false;
long g_saved_show_trade_lvls  = 1;
long g_saved_drag_trade_lvls  = 1;
long g_saved_event_mouse_move = 0;

string g_auto_template_name     = "";
int    g_auto_template_failures = 0;

bool   g_is_primary_instance = true;
long   g_instance_uid        = 0;
int    g_lock_file_handle    = INVALID_HANDLE;
bool   g_object_name_warned  = false; // usado en la sección de objetos del gráfico
bool   g_be_stage_warned     = false; // usado en la gestión de break-even
bool g_state_dirty        = false;

string g_cfg_key[CFG_MAX_KEYS];
double g_cfg_val[CFG_MAX_KEYS];
bool   g_cfg_used[CFG_MAX_KEYS];
int    g_cfg_count = 0;

ulong g_state_chk = 0;
bool  g_lock_owner_verified = false; // la primaria validó que el lock sigue siendo suyo (no hay otra instancia)
int   g_lock_attempts       = 0;     // reintentos de adquisición hechos por este gráfico (observador)

ulong g_next_mgmt_ms         = 0;
ulong g_next_adopt_ms        = 0;
ulong g_next_native_ms       = 0;
ulong g_next_heartbeat_ms    = 0;
ulong g_next_flush_ms        = 0;
ulong g_next_reconcile_ms    = 0;
ulong g_next_levels_ms       = 0;
ulong g_next_panel_slow_ms   = 0;
ulong g_last_chart_change_ms = 0;
ulong g_next_lock_retry_ms   = 0;
ulong g_next_limits_ms       = 0;
ulong g_flat_arm_until_ms    = 0;
ulong g_cancel_arm_until_ms  = 0;

// M-1: cola de cancelaciones diferidas. En cuenta real NO se puede usar
// Sleep() dentro de CancelPendingOrder (bloquearía el hilo del EA y retrasaría
// trailing/BE de otras posiciones). Cuando un reintento debe esperar, la
// orden se encola aquí y el siguiente OnTick/OnTimer reintenta sin bloquear.
struct SPendingCancel
{
   ulong  order_ticket;
   int    attempt;        // intentos ya consumidos (1-based al encolar)
   ulong  next_retry_ms;  // momento a partir del cual reintentar
   string context;
};
SPendingCancel g_pending_cancels[];

//+------------------------------------------------------------------+
//| PROTOTIPOS ADELANTADOS (sin argumentos por defecto)              |
//+------------------------------------------------------------------+
void   SetPanelStatus(string text, bool problem);
void   UpdatePanelInfo();
void   MarkPanelDirty();
bool   IsRetryableRetcode(uint retcode);
bool   IsSuccessfulTradeRetcode(uint retcode);
string TradeResultText();
bool   PositionBelongsToEA(ulong ticket);
int    FindPositionByOrderTicket(ulong order_ticket);
void   RefreshPartialCheckboxes();
void   RefreshManagementToggles();
void   RecalculateAllPositions();
void   RequestRedraw();
void   InvalidateZoneVolume(int idx);
void   InvalidateAllZoneVolumes();
void   UpdatePositionObjects(int idx);
void   SynchronizeLockedDraftZones();
void   LogExecution(string message, bool is_problem);
bool   CancelPendingOrder(ulong order_ticket, string context);
void   QueuePendingCancel(ulong order_ticket, int attempt, ulong delay_ms, string context);
void   ProcessPendingCancels();
void   FinishPendingCancel(ulong order_ticket, bool success, string context);
void   RemovePendingCancelAt(int idx);
void   ExecuteSelectedOrder();
void   ResetRuntimeState();
void   RaisePanelCanvasToFront();
void   SaveLiveConfig();
void   ApplyInputsToLive();
void   ClampLiveSettings();
void   RecomputeManagementFlags();
void   ApplyAccountModePolicy();
void   MarkStateDirty();
void   SavePositionsState();
bool   PanelPointInside(int px, int py);
void   GetPanelScreenBounds(int &x0, int &y0, int &x1, int &y1);
bool   IsPanelControlPoint(int px, int py);
int    ZoneDisplayNumber(int idx);
bool   ValidateZone(const SVisualPosition &p, string &err);
bool   PartialStageReached(int mgmt_idx, int stage);
int    FindPositionById(long id);
int    FindPositionByPositionTicket(ulong position_ticket);
int    FindManagementIndex(ulong ticket);
void   RemoveManagementIndex(int idx);
void   ReleaseIndicatorHandles();
void   DestroyPanel();
void   BuildPanel();
void   DestroySettingsPanel();
void   BuildSettingsPanel();
void   PurgeOldClosedZones();
void   CachePanelLayout(string include_prefix, string exclude_prefix, int anchor_x, int anchor_y,
                        string &out_names[], int &out_rel_x[], int &out_rel_y[], int &out_count);
void   ApplyPanelLayout(string &names[], int &rel_x[], int &rel_y[], int count,
                        int anchor_x, int anchor_y);
void   RequestDragRedraw();
double PositionAccruedCosts(ulong ticket);

//+------------------------------------------------------------------+
//| UTILIDADES - GESTIÓN EFICIENTE DE ARRAYS DINÁMICOS               |
//+------------------------------------------------------------------+

#define MAX_REASONABLE_ARRAY_SIZE 20000

template<typename T>
int EnsureArrayCapacity(T &array[], int required_size, int growth_factor_percent = 150)
{
   int current_size = ArraySize(array);
   if(current_size >= required_size) return current_size;

   if(required_size > MAX_REASONABLE_ARRAY_SIZE)
   {
      PrintFormat("%s: ERROR - Se pidió un array de %d elementos, por encima del límite de " +
                  "seguridad (%d). Se rechaza para evitar congelar la terminal; probablemente " +
                  "hay datos corruptos.", APP_NAME, required_size, MAX_REASONABLE_ARRAY_SIZE);
      return current_size;
   }

   int reserve_target = MathMax(required_size, (int)(current_size * growth_factor_percent / 100));
   if(reserve_target > MAX_REASONABLE_ARRAY_SIZE) reserve_target = MAX_REASONABLE_ARRAY_SIZE;
   int reserve = reserve_target - required_size;

   int result = ArrayResize(array, required_size, reserve);
   if(result < 0)
   {
      PrintFormat("%s: ERROR - No se pudo redimensionar array a %d elementos", APP_NAME, required_size);
      return current_size;
   }

   return result;
}

void InitializeArrays()
{
   ArrayResize(g_positions, 0, INITIAL_POSITIONS_CAPACITY);
   ArrayResize(g_management, 0, INITIAL_MANAGEMENT_CAPACITY);
   ArrayResize(g_panel_obj_names, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_panel_obj_rel_x, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_panel_obj_rel_y, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_settings_obj_names, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_settings_obj_rel_x, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_settings_obj_rel_y, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
}

//+------------------------------------------------------------------+
//| UTILIDADES - VALIDACIÓN DE DATOS (Separación de lógica)         |
//+------------------------------------------------------------------+

bool IsValidPrice(double price)
{
   return (price > 0.0 && price != EMPTY_VALUE);
}

bool ValidateZoneData(const SVisualPosition &pos, string &error_msg)
{
   error_msg = "";

   if(!IsValidPrice(pos.entry_price))
   {
      error_msg = "Precio de entrada inválido";
      return false;
   }

   if(!IsValidPrice(pos.tp_price))
   {
      error_msg = "Precio de TP inválido";
      return false;
   }

   if(!IsValidPrice(pos.sl_price))
   {
      error_msg = "Precio de SL inválido";
      return false;
   }

   bool is_long = (pos.type == PLANNER_POS_BUY);

   if(is_long && pos.sl_price >= pos.entry_price)
   {
      error_msg = "SL debe estar por debajo de entrada en compra";
      return false;
   }

   if(is_long && pos.tp_price <= pos.entry_price)
   {
      error_msg = "TP debe estar por encima de entrada en compra";
      return false;
   }

   if(!is_long && pos.sl_price <= pos.entry_price)
   {
      error_msg = "SL debe estar por encima de entrada en venta";
      return false;
   }

   if(!is_long && pos.tp_price >= pos.entry_price)
   {
      error_msg = "TP debe estar por debajo de entrada en venta";
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| UTILIDADES - CÁLCULOS DE PRECIO (Funciones puras)                |
//+------------------------------------------------------------------+

double CalculatePriceDistance(double price1, double price2)
{
   return MathAbs(price1 - price2);
}

double TicksToPrice(int ticks, const string symbol)
{
   double tick_size = GetTickSize(symbol);
   if(tick_size <= 0.0) return 0.0;

   return (double)ticks * tick_size;
}

//+------------------------------------------------------------------+
//| UTILIDADES - SEGURIDAD Y VALIDACIONES (Prevención de bugs)      |
//+------------------------------------------------------------------+

bool SafeArrayAccess(int index, int array_size, const string context = "")
{
   if(index < 0 || index >= array_size)
   {
      if(context != "")
         PrintFormat("%s: ERROR - Acceso fuera de límites en %s: index=%d, size=%d",
                     APP_NAME, context, index, array_size);
      return false;
   }
   return true;
}


bool IsValidTicket(ulong ticket)
{
   return (ticket > 0);
}

//+------------------------------------------------------------------+
//| UTILIDADES - ARITMÉTICA DE TIEMPO SEGURA                         |
//+------------------------------------------------------------------+

ulong SafeTimeAdd(ulong base_ms, ulong add_ms)
{
   if(base_ms > ULONG_MAX - add_ms)
      return ULONG_MAX;

   return base_ms + add_ms;
}

//+------------------------------------------------------------------+
//| UTILIDADES - OPERACIONES CON POSICIONES (Encapsulación)         |
//+------------------------------------------------------------------+

bool IsPositionExecutable(int idx)
{
   if(!SafeArrayAccess(idx, ArraySize(g_positions), "IsPositionExecutable"))
      return false;

   return (!g_positions[idx].is_executed &&
           !g_positions[idx].is_closed &&
           !g_positions[idx].is_degenerate);
}

bool HasActiveOrder(int idx)
{
   if(!SafeArrayAccess(idx, ArraySize(g_positions), "HasActiveOrder"))
      return false;

   return (g_positions[idx].order_ticket > 0 || g_positions[idx].ticket > 0);
}

//+------------------------------------------------------------------+
//| UTILIDADES - ACCESO SEGURO A ARRAYS DE GESTIÓN                   |
//+------------------------------------------------------------------+

bool IsManagementValid(int idx)
{
   if(!SafeArrayAccess(idx, ArraySize(g_management), "IsManagementValid"))
      return false;

   return IsValidTicket(g_management[idx].ticket);
}

//+------------------------------------------------------------------+
//| CONSOLIDACIÓN DE ACTUALIZACIONES DE UI                           |
//+------------------------------------------------------------------+

void UpdateUI(bool force_redraw = false)
{
   // En tester no-visual la UI está desactivada (sin panel ni objetos):
   // evitar cualquier llamada a ChartRedraw para no frenar el backtest.
   if(IsSilentTesterMode()) return;

   if(g_panel_dirty)
      UpdatePanelInfo();

   if(force_redraw || g_needs_redraw)
   {
      g_needs_redraw = false;
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| UTILIDADES - CONTEXTO DE EJECUCIÓN Y RELOJ                       |
//+------------------------------------------------------------------+
bool IsTesterContext()
{
   return (MQLInfoInteger(MQL_TESTER)       != 0 ||
           MQLInfoInteger(MQL_OPTIMIZATION) != 0 ||
           MQLInfoInteger(MQL_FORWARD)      != 0);
}

// Modo "silencioso" para el Strategy Tester: en backtest NO-visual no tiene
// sentido construir el panel gráfico ni lanzar el timer de refresco a 100 ms
// (ralentiza la optimización y genera miles de objetos sin usar). En modo
// visual sí se construye, porque el usuario necesita ver y manejar el panel.
bool IsSilentTesterMode()
{
   return (IsTesterContext() && MQLInfoInteger(MQL_VISUAL_MODE) == 0);
}

ulong NowMs()
{
   if(IsTesterContext()) return (ulong)TimeCurrent() * 1000;
   return GetTickCount64();
}

bool IsHedgingAccount()
{
   return ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) ==
           ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

//+------------------------------------------------------------------+
//| CACHÉ DE OBJETOS GRÁFICOS                                        |
//+------------------------------------------------------------------+

bool ObjectExistsCached(const string name)
{
   return (ObjectFind(0, name) >= 0);
}

void InvalidateObjectCache(const string name)
{
}

void ClearObjectCache()
{
}

//+------------------------------------------------------------------+
//| UTILIDADES - ESCRITURA DE OBJETOS SOLO SI CAMBIAN (Optimizado)  |
//+------------------------------------------------------------------+
void SetObjText(string name, string text)
{
   if(!ObjectExistsCached(name)) return;
   if(ObjectGetString(0, name, OBJPROP_TEXT) == text) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void SetObjInt(string name, ENUM_OBJECT_PROPERTY_INTEGER prop, long value)
{
   if(!ObjectExistsCached(name)) return;
   if(ObjectGetInteger(0, name, prop) == value) return;
   ObjectSetInteger(0, name, prop, value);
}

//+------------------------------------------------------------------+
//| UTILIDADES - OBJETOS                                             |
//+------------------------------------------------------------------+
void SafeObjectDelete(string name)
{
   if(!ObjectExistsCached(name)) return;

   g_suppress_object_events++;
   ObjectDelete(0, name);
   g_suppress_object_events--;

   InvalidateObjectCache(name);
}

bool ObjectCreateChecked(string name, ENUM_OBJECT type, datetime t1, double p1,
                         datetime t2, double p2, bool two_points)
{
   if(StringLen(name) > OBJECT_NAME_MAX_LEN)
   {
      if(!g_object_name_warned)
      {
         PrintFormat("%s: ERROR — el nombre de objeto '%s' tiene %d caracteres (máximo %d). " +
                     "Acorte InpObjectPrefix.", APP_NAME, name, StringLen(name), OBJECT_NAME_MAX_LEN);
         g_object_name_warned = true;
      }
      return false;
   }

   ResetLastError();
   bool ok = two_points ? ObjectCreate(0, name, type, 0, t1, p1, t2, p2)
                        : ObjectCreate(0, name, type, 0, t1, p1);

   if(!ok)
   {
      if(!g_object_name_warned)
      {
         PrintFormat("%s: ERROR — ObjectCreate('%s') falló (código %d).",
                     APP_NAME, name, GetLastError());
         g_object_name_warned = true;
      }
      return false;
   }

   return true;
}

void SetTooltipSafe(string name, string text)
{
   if(!ObjectExistsCached(name)) return;
   if(text == "") return;

   if(StringLen(text) > TOOLTIP_MAX_LEN)
      text = StringSubstr(text, 0, TOOLTIP_MAX_LEN - 3) + "...";

   if(ObjectGetString(0, name, OBJPROP_TOOLTIP) == text) return;
   ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
}

//+------------------------------------------------------------------+
//| UTILIDADES - NOMBRES, ARCHIVOS Y VALIDACIÓN DE TEXTO             |
//+------------------------------------------------------------------+
string ObjectNameForPosition(long id, string type)
{
   return InpObjectPrefix + "#" + _Symbol + "#" + (string)id + "#" + type;
}

string ObjectNameForPanel(string type)
{
   return InpObjectPrefix + "#PANEL#" + type;
}

string PartialLineName(long id, int stage)
{
   return ObjectNameForPosition(id, "LINE_TPP" + IntegerToString(stage));
}

string PartialTextName(long id, int stage)
{
   return ObjectNameForPosition(id, "TXT_TPP" + IntegerToString(stage));
}

string SanitizeFileToken(string s)
{
   string out = "";
   int    len = StringLen(s);

   for(int i = 0; i < len; i++)
   {
      ushort c  = StringGetCharacter(s, i);
      bool   ok = (c >= '0' && c <= '9') ||
                  (c >= 'A' && c <= 'Z') ||
                  (c >= 'a' && c <= 'z') ||
                  c == '_' || c == '-';
      out += ok ? ShortToString(c) : "_";
   }

   if(out == "") out = "SYM";
   return out;
}

string AccountLoginToken()
{
   string server = SanitizeFileToken(AccountInfoString(ACCOUNT_SERVER));
   return server + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
}

string InstanceFileToken()
{
   string token = AccountLoginToken() + "_" + SanitizeFileToken(_Symbol) + "_M" +
                  IntegerToString(InpMagicNumber);

   if(InpInstanceTag != "") token += "_" + SanitizeFileToken(InpInstanceTag);

   return token;
}

bool IsValidDecimal(string text, double &output)
{
   StringTrimLeft(text);
   StringTrimRight(text);

   int len = StringLen(text);
   if(len <= 0) return false;

   int    separators = 0, digits = 0;
   string normalized = "";

   for(int i = 0; i < len; i++)
   {
      ushort c = StringGetCharacter(text, i);

      if(c == '.' || c == ',')
      {
         separators++;
         if(separators > 1) return false;
         normalized += ".";
         continue;
      }

      if(c < '0' || c > '9') return false;

      digits++;
      normalized += ShortToString(c);
   }

   if(digits == 0) return false;

   output = StringToDouble(normalized);
   return true;
}

bool IsValidSignedDecimal(string text, double &output)
{
   StringTrimLeft(text);
   StringTrimRight(text);

   if(StringLen(text) == 0) return false;

   bool   negative = false;
   ushort c0       = StringGetCharacter(text, 0);

   if(c0 == '-' || c0 == '+')
   {
      negative = (c0 == '-');
      text     = StringSubstr(text, 1);
   }

   if(!IsValidDecimal(text, output)) return false;
   if(negative) output = -output;

   return true;
}

//+------------------------------------------------------------------+
//| UTILIDADES - PRECIOS Y NORMALIZACIÓN                             |
//+------------------------------------------------------------------+
double GetTickValueForRisk(string symbol)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tick_value <= 0.0) tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) return 0.0;

   return tick_value / tick_size;
}

double GetTickValueForProfit(string symbol)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   if(tick_value <= 0.0) tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) return 0.0;

   return tick_value / tick_size;
}

double GetTickSize(string symbol)
{
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) tick_size = SymbolInfoDouble(symbol, SYMBOL_POINT);
   return tick_size;
}

double NormalizeToTick(double price)
{
   double tick = GetTickSize(_Symbol);
   if(tick <= 0.0) return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathRound(price / tick) * tick, _Digits);
}

int VolumeStepDigits(double step)
{
   if(step <= 0.0) return 2;

   int    digits = 0;
   double s      = step;
   while(digits < 8 && MathAbs(s - MathRound(s)) > 1e-9)
   {
      s *= 10.0;
      digits++;
   }
   return digits;
}

double NormalizeVolume(string symbol, double volume, bool &below_min)
{
   below_min = false;

   double step  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minv  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxv  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double limit = SymbolInfoDouble(symbol, SYMBOL_VOLUME_LIMIT);

   if(step <= 0.0) step = (minv > 0.0) ? minv : 0.01;

   int digits = VolumeStepDigits(step);

   volume = MathFloor(volume / step + 1e-8) * step;
   volume = NormalizeDouble(volume, digits);

   if(volume < minv - 1e-9)
   {
      below_min = true;
      return 0.0;
   }

   if(maxv  > 0.0 && volume > maxv)  volume = NormalizeDouble(maxv,  digits);
   if(limit > 0.0 && volume > limit) volume = NormalizeDouble(limit, digits);

   return volume;
}

int VolumeDecimalsFromStep(const string sym)
{
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) return 2;
   return VolumeStepDigits(step);
}

double EffectiveRiskPercent()
{
   if(g_effective_risk_percent >= 0.0) return g_effective_risk_percent;
   return MathMax(0.01, MathMin(100.0, InpRiskPercent));
}

string FormatMoney(double value)
{
   double a    = MathAbs(value);
   string sign = (value < 0.0) ? "-" : "";
   if(a >= 1000000.0) return sign + DoubleToString(a / 1000000.0, 2) + "M";
   if(a >= 1000.0)    return sign + DoubleToString(a / 1000.0,    2) + "K";
   return sign + DoubleToString(a, 2);
}

string FormatMoneyFull(double value)
{
   return DoubleToString(value, 2);
}

string TradeResultText()
{
   return StringFormat("retcode %u (%s)",
                       g_trade_object.ResultRetcode(),
                       g_trade_object.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| UTILIDADES - COLOR                                               |
//+------------------------------------------------------------------+
// Rango efectivo de transparencia: se limita a [0..92] para que el relleno de
// las zonas conserve siempre un mínimo de translucidez (~8% de opacidad) y no
// llegue a ocultar por completo las velas ni los niveles del gráfico.
// El usuario sigue pudiendo elegir cualquier valor dentro de ese rango.
#define ZONE_TRANSPARENCY_MAX_EFFECTIVE 92

color ApplyTransparency(color original, int percent)
{
   percent = (int)MathMax(0, MathMin(ZONE_TRANSPARENCY_MAX_EFFECTIVE, percent));

   int src = (int)original;
   int bg  = (int)ChartGetInteger(0, CHART_COLOR_BACKGROUND);

   int r1 = src & 0xFF, g1 = (src >> 8) & 0xFF, b1 = (src >> 16) & 0xFF;
   int r2 = bg  & 0xFF, g2 = (bg  >> 8) & 0xFF, b2 = (bg  >> 16) & 0xFF;

   double opacity = (100.0 - percent) / 100.0;
   int rf = (int)MathRound(r1 * opacity + r2 * (1.0 - opacity));
   int gf = (int)MathRound(g1 * opacity + g2 * (1.0 - opacity));
   int bf = (int)MathRound(b1 * opacity + b2 * (1.0 - opacity));

   rf = (int)MathMax(0, MathMin(255, rf));
   gf = (int)MathMax(0, MathMin(255, gf));
   bf = (int)MathMax(0, MathMin(255, bf));

   return (color)(rf | (gf << 8) | (bf << 16));
}

//+------------------------------------------------------------------+
//| MERCADO - UMBRALES SEPARADOS (STOPS vs FREEZE)                   |
//+------------------------------------------------------------------+
double SymbolPointSafe(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0) point = GetTickSize(symbol);
   return point;
}

double StopsThreshold(string symbol)
{
   double point = SymbolPointSafe(symbol);
   if(point <= 0.0) return 0.0;

   long lvl = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(lvl < 0) lvl = 0;

   return (double)lvl * point;
}

double FreezeThreshold(string symbol)
{
   double point = SymbolPointSafe(symbol);
   if(point <= 0.0) return 0.0;

   long lvl = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   if(lvl < 0) lvl = 0;

   return (double)lvl * point;
}

bool PositionIsFrozen(ulong ticket, string &reason)
{
   reason = "";

   double freeze = FreezeThreshold(_Symbol);
   if(freeze <= 0.0) return false;
   if(!PositionSelectByTicket(ticket)) return false;

   long   type = PositionGetInteger(POSITION_TYPE);
   double sl   = PositionGetDouble(POSITION_SL);
   double tp   = PositionGetDouble(POSITION_TP);

   double price = (type == POSITION_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(price <= 0.0) return false;

   if(sl > 0.0 && MathAbs(price - sl) < freeze)
   {
      reason = "el precio está dentro del freeze level respecto al SL actual";
      return true;
   }

   if(tp > 0.0 && MathAbs(price - tp) < freeze)
   {
      reason = "el precio está dentro del freeze level respecto al TP actual";
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| MERCADO - FRESCURA DE COTIZACIÓN                                 |
//+------------------------------------------------------------------+
bool GetTradableTick(string symbol, MqlTick &tick, string &reason)
{
   reason = "";

   if(!SymbolInfoTick(symbol, tick))
   {
      reason = "no se pudo leer la cotización de " + symbol;
      return false;
   }

   if(tick.ask <= 0.0 || tick.bid <= 0.0)
   {
      reason = "la cotización de " + symbol + " no es válida (bid/ask <= 0)";
      return false;
   }

   if(IsTesterContext()) return true;

   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      reason = "el terminal no está conectado al servidor";
      return false;
   }

   long age_ms = (long)TimeCurrent() * 1000 - (long)tick.time_msc;
   if(age_ms > QUOTE_MAX_AGE_MS)
   {
      reason = StringFormat("la última cotización de %s tiene %.1f s de antigüedad " +
                            "(máximo %.1f s); ¿mercado cerrado?",
                            symbol, age_ms / 1000.0, QUOTE_MAX_AGE_MS / 1000.0);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| MERCADO - LLENADO, ÓRDENES PENDIENTES Y OBJETO DE TRADE          |
//+------------------------------------------------------------------+

bool SymbolAllowsPendingType(string symbol, ENUM_ORDER_TYPE type)
{
   long modes = SymbolInfoInteger(symbol, SYMBOL_ORDER_MODE);

   switch(type)
   {
      case ORDER_TYPE_BUY_LIMIT:
      case ORDER_TYPE_SELL_LIMIT: return ((modes & SYMBOL_ORDER_LIMIT) != 0);
      case ORDER_TYPE_BUY_STOP:
      case ORDER_TYPE_SELL_STOP:  return ((modes & SYMBOL_ORDER_STOP)  != 0);
      default:                    return ((modes & SYMBOL_ORDER_MARKET) != 0);
   }
}

string OrderTypeText(ENUM_ORDER_TYPE type)
{
   switch(type)
   {
      case ORDER_TYPE_BUY:        return "COMPRA a mercado";
      case ORDER_TYPE_SELL:       return "VENTA a mercado";
      case ORDER_TYPE_BUY_LIMIT:  return "BUY LIMIT";
      case ORDER_TYPE_SELL_LIMIT: return "SELL LIMIT";
      case ORDER_TYPE_BUY_STOP:   return "BUY STOP";
      case ORDER_TYPE_SELL_STOP:  return "SELL STOP";
      default:                    return "orden";
   }
}

void ConfigureTradeObject()
{
   g_trade_object.SetExpertMagicNumber((ulong)InpMagicNumber);
   g_trade_object.SetDeviationInPoints((ulong)MathMax(0, g_max_deviation));
   g_trade_object.SetTypeFillingBySymbol(_Symbol);
   g_trade_object.SetAsyncMode(false);
   g_trade_object.LogLevel(LOG_LEVEL_ERRORS);
}

void PrepareTradeObjectForClose()
{
   g_trade_object.SetDeviationInPoints((ulong)MathMax(0, g_max_deviation));
   g_trade_object.SetTypeFillingBySymbol(_Symbol);
}

bool PositionBelongsToEA(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return false;
   return true;
}

//+------------------------------------------------------------------+
//| DINERO <-> PRECIO (C-5 y dimensionado por riesgo)                |
//+------------------------------------------------------------------+
bool ProfitForMove(string symbol, ENUM_ORDER_TYPE type, double volume, double open, double close,
                   double &profit)
{
   profit = 0.0;
   if(volume <= 0.0 || open <= 0.0 || close <= 0.0) return false;
   return OrderCalcProfit(type, symbol, volume, open, close, profit);
}

double MoneyToPriceDistance(string symbol, ENUM_ORDER_TYPE type, double volume,
                            double reference_price, double money)
{
   double tick = GetTickSize(symbol);
   if(tick <= 0.0 || volume <= 0.0 || money <= 0.0 || reference_price <= 0.0) return 0.0;

   double profit_per_tick = 0.0;
   bool   is_long         = (type == ORDER_TYPE_BUY);
   double probe           = is_long ? (reference_price + tick) : (reference_price - tick);

   if(!ProfitForMove(symbol, type, volume, reference_price, probe, profit_per_tick) ||
      MathAbs(profit_per_tick) <= 0.0)
   {
      double tv = GetTickValueForProfit(symbol);
      if(tv <= 0.0) return 0.0;
      profit_per_tick = tv * tick * volume;
      if(profit_per_tick <= 0.0) return 0.0;
   }

   double profit_abs = MathAbs(profit_per_tick);
   if(profit_abs <= 0.0) return 0.0;
   double ticks = money / profit_abs;
   return ticks * tick;
}

double PositionAccruedCosts(ulong ticket)
{
   double costs = 0.0;

   if(PositionSelectByTicket(ticket))
      costs -= PositionGetDouble(POSITION_SWAP);

   if(HistorySelectByPosition(ticket))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0) continue;

         costs -= HistoryDealGetDouble(deal, DEAL_COMMISSION);
      }
   }

   return (costs > 0.0) ? costs : 0.0;
}

//+------------------------------------------------------------------+
//| RIESGO - CÁLCULO DE VOLUMEN (L-2: sin doble spread)              |
//+------------------------------------------------------------------+
double CalculateVolumeEx(string symbol, ENUM_PLANNER_POS_TYPE type,
                         double entry, double stop, bool &below_min, string &reason)
{
   below_min = false;
   reason    = "";

   if(entry <= 0.0)
   {
      reason = "el precio de entrada de la posición no es válido (debe ser > 0)";
      return 0.0;
   }

   double raw = 0.0;

   if(InpVolumeMode == VOL_FIXED)
   {
      raw = g_volume;

      if(raw <= 0.0)
      {
         reason = "el lotaje fijo configurado es cero; escriba un volumen en el panel";
         return 0.0;
      }
   }
   else
   {
      if(MathAbs(entry - stop) <= 0.0)
      {
         reason = "la distancia entre la entrada y el Stop Loss es cero; separe el SL";
         return 0.0;
      }

      ENUM_ORDER_TYPE otype = (type == PLANNER_POS_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      double loss_per_lot = 0.0;
      if(!ProfitForMove(symbol, otype, 1.0, entry, stop, loss_per_lot) || loss_per_lot >= 0.0)
      {
         double tick_value = GetTickValueForRisk(symbol);
         if(tick_value <= 0.0)
         {
            reason = "el bróker no reporta datos suficientes para dimensionar por riesgo en " +
                     symbol;
            return 0.0;
         }
         loss_per_lot = -MathAbs(entry - stop) * tick_value;
      }

      double risk_per_lot = MathAbs(loss_per_lot) + MathMax(0.0, InpRiskCommissionPerLot);
      if(risk_per_lot <= 0.0)
      {
         reason = "no se pudo calcular el riesgo por lote con los datos actuales de " + symbol;
         return 0.0;
      }

      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double capital = 0.0;

      switch(InpRiskBase)
      {
         case RISK_EQUITY:  capital = equity;  break;
         case RISK_BALANCE: capital = balance; break;
         default:           capital = MathMin(equity, balance); break;
      }

      if(capital <= 0.0)
      {
         static datetime last_warning = 0;
         if(TimeCurrent() - last_warning > 60)
         {
            PrintFormat("%s: capital no válido (%s) para dimensionar por riesgo.",
                        APP_NAME, DoubleToString(capital, 2));
            last_warning = TimeCurrent();
         }
         reason = "el capital de la cuenta no es válido (equity/balance <= 0)";
         return 0.0;
      }

      double risk_amount = capital * (EffectiveRiskPercent() / 100.0);
      raw = risk_amount / risk_per_lot;
   }

   double normalized = NormalizeVolume(symbol, raw, below_min);

   if(below_min)
   {
      if(InpVolumeMode == VOL_FIXED)
         reason = StringFormat(
            "el volumen fijo configurado (%s lotes) queda por debajo del mínimo del símbolo (%s).",
            DoubleToString(raw, 4),
            DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), 4));
      else
         reason = StringFormat(
            "el riesgo del %.2f%% con este SL exige %s lotes, por debajo del mínimo (%s). " +
            "Reduzca la distancia del SL o acepte más riesgo.",
            EffectiveRiskPercent(),
            DoubleToString(raw, 4),
            DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), 4));

      return 0.0;
   }

   if(normalized <= 0.0)
   {
      reason = StringFormat("el volumen quedó en cero al ajustarlo al paso del símbolo (%s)",
                            DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP), 4));
      return 0.0;
   }

   ENUM_ORDER_TYPE margin_order_type = (type == PLANNER_POS_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price_for_margin = (type == PLANNER_POS_BUY)
                             ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(symbol, SYMBOL_BID);
   double required_margin = 0.0;

   if(price_for_margin > 0.0 &&
      OrderCalcMargin(margin_order_type, symbol, normalized, price_for_margin, required_margin))
   {
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(required_margin > free_margin)
      {
         reason = StringFormat("margen insuficiente: requiere %s, disponible %s",
                               FormatMoneyFull(required_margin), FormatMoneyFull(free_margin));
         return 0.0;
      }
   }

   return normalized;
}

double CalculateVolumeSimple(string symbol, ENUM_PLANNER_POS_TYPE type,
                             double entry, double stop)
{
   bool   below_min;
   string reason;
   return CalculateVolumeEx(symbol, type, entry, stop, below_min, reason);
}

//+------------------------------------------------------------------+
//| RIESGO - CACHÉ DE VOLUMEN POR POSICIÓN                           |
//+------------------------------------------------------------------+
void InvalidateZoneVolume(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return;
   g_positions[idx].qty_valid = false;
}

void InvalidateAllZoneVolumes()
{
   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      if(g_positions[i].id < 0) continue;
      g_positions[i].qty_valid = false;
   }
}

void EnsureZoneVolume(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return;

   if(g_positions[idx].is_executed && g_positions[idx].ticket > 0 &&
      PositionSelectByTicket(g_positions[idx].ticket))
   {
      g_positions[idx].qty       = PositionGetDouble(POSITION_VOLUME);
      g_positions[idx].qty_valid = true;
      return;
   }

   if(g_positions[idx].qty_valid) return;

   g_positions[idx].qty = CalculateVolumeSimple(_Symbol, g_positions[idx].type,
                                                g_positions[idx].entry_price,
                                                g_positions[idx].sl_price);
   g_positions[idx].qty_valid = true;
}

//+------------------------------------------------------------------+
//| ValidateStopDistance                                             |
//+------------------------------------------------------------------+
bool ValidateStopDistance(string symbol, ENUM_PLANNER_POS_TYPE type,
                          double entry_reference, double close_reference,
                          double sl, double tp, string &reason)
{
   reason = "";

   double tick_size = GetTickSize(symbol);
   if(tick_size <= 0.0 || entry_reference <= 0.0 || close_reference <= 0.0)
   {
      reason = "no se pudo leer el precio/tick del símbolo";
      return false;
   }

   bool is_long = (type == PLANNER_POS_BUY);

   if(sl > 0.0)
   {
      if(is_long && sl >= entry_reference)
      {
         reason = "el SL debe quedar por debajo del precio de entrada en una compra";
         return false;
      }
      if(!is_long && sl <= entry_reference)
      {
         reason = "el SL debe quedar por encima del precio de entrada en una venta";
         return false;
      }
   }

   if(tp > 0.0)
   {
      if(is_long && tp <= entry_reference)
      {
         reason = "el TP debe quedar por encima del precio de entrada en una compra";
         return false;
      }
      if(!is_long && tp >= entry_reference)
      {
         reason = "el TP debe quedar por debajo del precio de entrada en una venta";
         return false;
      }
   }

   double min_distance = StopsThreshold(symbol);
   if(min_distance <= 0.0) return true;

   if(sl > 0.0)
   {
      double dist = MathAbs(close_reference - sl);
      if(dist < min_distance)
      {
         reason = StringFormat("SL a %.1f ticks del precio de cierre; mínimo %.1f ticks en %s " +
                               "(stops level)", dist / tick_size, min_distance / tick_size, symbol);
         return false;
      }
   }

   if(tp > 0.0)
   {
      double dist = MathAbs(close_reference - tp);
      if(dist < min_distance)
      {
         reason = StringFormat("TP a %.1f ticks del precio de cierre; mínimo %.1f ticks en %s " +
                               "(stops level)", dist / tick_size, min_distance / tick_size, symbol);
         return false;
      }
   }

   return true;
}

bool ValidateZone(const SVisualPosition &p, string &err)
{
   return ValidateZoneData(p, err);
}

//+------------------------------------------------------------------+
//| BÚSQUEDA DE POSICIONES Y REGISTROS                               |
//+------------------------------------------------------------------+

int FindPositionById(long id)
{
   if(id < 0) return -1;

   if(id == g_search_cache.last_position_id &&
      g_search_cache.last_position_result >= 0 &&
      g_search_cache.last_position_result < ArraySize(g_positions) &&
      g_positions[g_search_cache.last_position_result].id == id)
      return g_search_cache.last_position_result;

   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      if(g_positions[i].id == id)
      {
         g_search_cache.last_position_id = id;
         g_search_cache.last_position_result = i;
         return i;
      }
   }

   return -1;
}

int FindPositionByOrderTicket(ulong order_ticket)
{
   if(order_ticket == 0) return -1;
   for(int i = 0; i < ArraySize(g_positions); i++)
      if(g_positions[i].order_ticket == order_ticket) return i;
   return -1;
}

int FindPositionByPositionTicket(ulong position_ticket)
{
   if(position_ticket == 0) return -1;
   for(int i = 0; i < ArraySize(g_positions); i++)
      if(g_positions[i].ticket == position_ticket) return i;
   return -1;
}

int GetTargetPositionIndex()
{
   return (g_selected_id >= 0) ? FindPositionById(g_selected_id) : -1;
}

bool ZoneHasLivePendingOrder(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return false;
   return (g_positions[idx].order_ticket > 0 && !g_positions[idx].is_executed);
}

int FindManagementIndex(ulong ticket)
{
   if(ticket == 0) return -1;

   if(ticket == g_search_cache.last_mgmt_ticket &&
      g_search_cache.last_mgmt_result >= 0 &&
      g_search_cache.last_mgmt_result < ArraySize(g_management) &&
      g_management[g_search_cache.last_mgmt_result].ticket == ticket)
      return g_search_cache.last_mgmt_result;

   for(int i = 0; i < ArraySize(g_management); i++)
   {
      if(g_management[i].ticket == ticket)
      {
         g_search_cache.last_mgmt_ticket = ticket;
         g_search_cache.last_mgmt_result = i;
         return i;
      }
   }

   return -1;
}

//+------------------------------------------------------------------+
//| FrozenStage                                                      |
//+------------------------------------------------------------------+
bool FrozenStage(const SVisualPosition &pos, int stage, bool &active, double &price,
                 double &pct)
{
   active = false;
   price  = 0.0;
   pct    = 0.0;

   if(pos.ticket == 0) return false;

   int m = FindManagementIndex(pos.ticket);
   if(m < 0) return false;

   active = (g_management[m].plan_partials_on && g_management[m].plan_stage_active[stage]);
   price  = g_management[m].plan_stage_price[stage];
   pct    = g_management[m].plan_stage_pct[stage];

   return true;
}

bool PartialStageActive(const SVisualPosition &pos, int stage)
{
   if(stage < 0 || stage >= PARTIAL_STAGES) return false;

   bool   frozen_active;
   double frozen_price, frozen_pct;
   if(FrozenStage(pos, stage, frozen_active, frozen_price, frozen_pct))
      return frozen_active;

   if(!g_partial_enabled[stage])   return false;
   if(g_partial_pct[stage] <= 0.0) return false;

   if(pos.partial_is_manual[stage])
      return (pos.partial_manual_price[stage] > 0.0);

   return (g_partial_mult[stage] > 0.0);
}

double PartialStagePrice(const SVisualPosition &pos, int stage)
{
   if(stage < 0 || stage >= PARTIAL_STAGES) return 0.0;

   bool   frozen_active;
   double frozen_price, frozen_pct;
   if(FrozenStage(pos, stage, frozen_active, frozen_price, frozen_pct))
      return frozen_price;

   if(pos.partial_is_manual[stage])
      return pos.partial_manual_price[stage];

   bool   is_long     = (pos.type == PLANNER_POS_BUY);
   double target_dist = is_long ? (pos.tp_price - pos.entry_price)
                                : (pos.entry_price - pos.tp_price);
   double fraction    = g_partial_mult[stage] / 100.0;

   return is_long ? (pos.entry_price + fraction * target_dist)
                  : (pos.entry_price - fraction * target_dist);
}

double PartialStagePercent(const SVisualPosition &pos, int stage)
{
   bool   frozen_active;
   double frozen_price, frozen_pct;
   if(FrozenStage(pos, stage, frozen_active, frozen_price, frozen_pct))
      return frozen_pct;

   return g_partial_pct[stage];
}

bool PartialStagePriceUsable(const SVisualPosition &pos, int stage)
{
   double price = PartialStagePrice(pos, stage);
   if(price <= 0.0) return false;

   return (pos.type == PLANNER_POS_BUY) ? (price > pos.entry_price)
                                        : (price < pos.entry_price);
}

string PartialStageLabelText(const SVisualPosition &pos, int stage)
{
   string tag = "TP" + IntegerToString(stage + 1);
   if(pos.partial_is_manual[stage]) tag += "*";
   if(!PartialStagePriceUsable(pos, stage)) tag += "!";

   return tag + "  " + DoubleToString(PartialStagePercent(pos, stage), 0) + "%  ";
}

string MainLevelLabelText(double price)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return "  " + DoubleToString(price, digits);
}

double PartialsOuterBound(const SVisualPosition &pos)
{
   bool   is_long = (pos.type == PLANNER_POS_BUY);
   double bound   = pos.tp_price;

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      if(!PartialStageActive(pos, s)) continue;

      double stage_price = PartialStagePrice(pos, s);
      if(stage_price <= 0.0) continue;

      bound = is_long ? MathMax(bound, stage_price) : MathMin(bound, stage_price);
   }

   return bound;
}

//+------------------------------------------------------------------+
//| TEMA DEL PANEL - DISEÑO MODERNO Y PROFESIONAL                    |
//+------------------------------------------------------------------+

color ColorBackground()   { return C'17,19,24';    }
color ColorHeaderBar()    { return C'23,26,33';    }
color ColorSurface()      { return C'28,31,38';    }
color ColorSurfaceAlt()   { return C'22,25,31';    }
color ColorBorder()       { return C'48,53,65';    }
color ColorBorderSoft()   { return C'35,39,48';    }

color ColorAccent()       { return C'64,140,255';  }
color ColorAccentDim()    { return C'45,98,185';   }

color ColorTextStrong()   { return C'242,245,250'; }
color ColorTextWeak()     { return C'160,167,181'; }
color ColorTextMuted()    { return C'118,125,138'; }
color ColorTextDisabled() { return C'90,96,108';   }

color ColorSuccess()      { return C'16,185,129';  }
color ColorWarning()      { return C'245,158,11';  }
color ColorDanger()       { return C'239,68,68';   }

color ColorButtonNeutralBg()     { return C'40,45,56';    }
color ColorButtonNeutralBorder() { return C'56,62,76';    }
color ColorButtonNeutralText()   { return C'215,220,228'; }

color ColorBuyButton()          { return ColorSuccess();   }
color ColorBuyButtonBorder()    { return C'13,148,103';    }
color ColorSellButton()         { return ColorDanger();    }
color ColorSellButtonBorder()   { return C'191,54,54';     }
color ColorActionButton()       { return ColorAccent();    }
color ColorActionButtonBorder() { return ColorAccentDim(); }

color ColorEditBackground(bool enabled) { return enabled ? ColorSurface()    : ColorSurfaceAlt();   }
color ColorEditText(bool enabled)       { return enabled ? ColorTextStrong() : ColorTextDisabled(); }
color ColorEditBorder(bool enabled)     { return enabled ? ColorBorder()     : ColorBorderSoft();   }

color ColorPartialLevel() { return C'250,204,21'; }

//+------------------------------------------------------------------+
//| PANEL - ESCALADO (S-4: helpers únicos S() y F())                 |
//+------------------------------------------------------------------+
int S(int px)
{
   return (int)MathRound(px * g_panel_zoom);
}

int F(int pt)
{
   return (int)MathMax(6, MathMin(28, (int)MathRound(pt * g_panel_zoom)));
}

//+------------------------------------------------------------------+
//| PANEL - CONVERSIONES DE COORDENADAS                              |
//+------------------------------------------------------------------+
int PanelContentWidth() { return g_panel_width - 2 * PANEL_MARGIN; }
int PanelButtonWidth()  { return (PanelContentWidth() - PANEL_BUTTON_GAP) / 2; }
int PanelThirdWidth()   { return (PanelContentWidth() - 2 * PANEL_BUTTON_GAP) / 3; }
int PanelFullRowWidth() { return PanelButtonWidth() * 2 + PANEL_BUTTON_GAP; }
int PanelHeaderOffsetY(){ return -PANEL_MARGIN - PANEL_HANDLE_HEIGHT; }
int PanelHeaderHeight() { return PANEL_MARGIN + PANEL_HANDLE_HEIGHT; }

int GearOffsetX()     { return 0; }
int GearOffsetY()     { return PanelHeaderOffsetY() + (PanelHeaderHeight() - PANEL_GEAR_SIZE) / 2; }
int PanelEditOffsetX(){ return g_panel_width - 2 * PANEL_MARGIN - PANEL_EDIT_WIDTH; }
int PadlockOffsetX()  { return PANEL_GEAR_SIZE + 12; }
int PadlockOffsetY()  { return PanelHeaderOffsetY() + (PanelHeaderHeight() - PANEL_PADLOCK_SIZE) / 2; }

int TPEditWidth()
{
   int fixed_part = PANEL_TP_CHK_W + PANEL_TP_LABEL_W + PANEL_TP_COL_INDENT + 12 +
                    PANEL_TP_UNIT_W + 12 +
                    PANEL_TP_BLOCK_GAP + PANEL_TP_UNIT_W + 12;
   int available  = PanelContentWidth() - fixed_part;
   int w          = available / 2;

   return (int)MathMax(30, MathMin(60, w));
}

int TPCheckboxOffsetX() { return 0; }
int TPLabelOffsetX()    { return PANEL_TP_CHK_W; }
int TPEditMultOffsetX() { return TPLabelOffsetX()    + PANEL_TP_LABEL_W + PANEL_TP_COL_INDENT + 12; }
int TPUnitMultOffsetX() { return TPEditMultOffsetX() + TPEditWidth()    + 12; }
int TPEditPctOffsetX()  { return TPUnitMultOffsetX() + PANEL_TP_UNIT_W  + PANEL_TP_BLOCK_GAP; }
int TPUnitPctOffsetX()  { return TPEditPctOffsetX()  + TPEditWidth()    + 12; }

int TPRowOffsetY(int stage) { return PANEL_TP_ROW0_Y + stage * PANEL_TP_ROW_STEP; }

int PanelTopY()  { return g_panel_y + S(PanelHeaderOffsetY()); }
int PanelLeftX() { return g_panel_x - S(PANEL_MARGIN); }
int PanelAbsX(int offset_x) { return g_panel_x + S(offset_x); }
int PanelAbsY(int offset_y) { return PanelTopY() + S(offset_y); }
int PanelHeaderAbsY(int offset_y) { return g_panel_y + S(offset_y); }

void GetPanelScreenBounds(int &x0, int &y0, int &x1, int &y1)
{
   x0 = PanelLeftX();
   y0 = PanelTopY();
   x1 = x0 + S(g_panel_width);
   y1 = y0 + S(PANEL_HEIGHT);
}

bool PanelPointInside(int px, int py)
{
   if(!g_panel_built) return false;

   int x0, y0, x1, y1;
   GetPanelScreenBounds(x0, y0, x1, y1);

   return (px >= x0 && px <= x1 && py >= y0 && py <= y1);
}

//+------------------------------------------------------------------+
//| ==== PARTE 2/4 ====                                              |
//| Dibujo de posiciones, gestión de posiciones visuales, política   |
//| de cuenta                                                        |
//| y congelación del plan de gestión.                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| PANEL - PUNTOS DE CONTROL INTERACTIVOS                           |
//+------------------------------------------------------------------+

struct SControlBounds
{
   string name;
   int    x;
   int    y;
   int    width;
   int    height;
};

SControlBounds g_control_bounds[];
int g_control_bounds_count = 0;
bool g_control_bounds_valid = false;

void InvalidateControlBounds()
{
   g_control_bounds_valid = false;
}

void CacheControlBounds()
{
   ArrayResize(g_control_bounds, 0);
   g_control_bounds_count = 0;

   for(int i = 0; i < g_panel_obj_count; i++)
   {
      string name = g_panel_obj_names[i];
      if(!ObjectIsInteractiveControl(name)) continue;

      int n = ArraySize(g_control_bounds);
      ArrayResize(g_control_bounds, n + 1);

      g_control_bounds[n].name = name;
      g_control_bounds[n].x = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
      g_control_bounds[n].y = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
      g_control_bounds[n].width = (int)ObjectGetInteger(0, name, OBJPROP_XSIZE);
      g_control_bounds[n].height = (int)ObjectGetInteger(0, name, OBJPROP_YSIZE);

      g_control_bounds_count++;
   }

   for(int j = 0; j < g_settings_obj_count; j++)
   {
      string name = g_settings_obj_names[j];
      if(!ObjectIsInteractiveControl(name)) continue;

      int n = ArraySize(g_control_bounds);
      ArrayResize(g_control_bounds, n + 1);

      g_control_bounds[n].name = name;
      g_control_bounds[n].x = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
      g_control_bounds[n].y = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
      g_control_bounds[n].width = (int)ObjectGetInteger(0, name, OBJPROP_XSIZE);
      g_control_bounds[n].height = (int)ObjectGetInteger(0, name, OBJPROP_YSIZE);

      g_control_bounds_count++;
   }

   g_control_bounds_valid = true;
}

bool ObjectIsInteractiveControl(string name)
{
   if(!ObjectExistsCached(name)) return false;

   ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
   return (type == OBJ_EDIT || type == OBJ_BUTTON);
}

bool IsPanelControlPoint(int px, int py)
{
   if(!g_control_bounds_valid)
      CacheControlBounds();

   for(int i = 0; i < g_control_bounds_count; i++)
   {
      if(g_control_bounds[i].width <= 0 || g_control_bounds[i].height <= 0)
         continue;

      if(px >= g_control_bounds[i].x &&
         px <= g_control_bounds[i].x + g_control_bounds[i].width &&
         py >= g_control_bounds[i].y &&
         py <= g_control_bounds[i].y + g_control_bounds[i].height)
         return true;
   }

   return false;
}

void GetSettingsScreenBounds(int &x0, int &y0, int &x1, int &y1)
{
   int rows_h = SETTINGS_FIELDS * SETTINGS_ROW_STEP;
   int total  = SETTINGS_HEADER_H + rows_h + SETTINGS_FOOTER_H + 2 * SETTINGS_MARGIN;

   x0 = g_settings_x;
   y0 = g_settings_y;
   x1 = x0 + S(SETTINGS_WIDTH);
   y1 = y0 + S(total);
}

bool SettingsPointInside(int px, int py)
{
   if(!g_settings_panel_built) return false;

   int x0, y0, x1, y1;
   GetSettingsScreenBounds(x0, y0, x1, y1);

   return (px >= x0 && px <= x1 && py >= y0 && py <= y1);
}

bool PointOverAnyPanel(int px, int py)
{
   return (PanelPointInside(px, py) || SettingsPointInside(px, py));
}

//+------------------------------------------------------------------+
//| GRÁFICO - CONVERSIONES PRECIO <-> PÍXEL                          |
//+------------------------------------------------------------------+
void InvalidatePricePerPixel()
{
   g_price_per_pixel_dirty = true;
}

double PricePerPixel()
{
   if(!g_price_per_pixel_dirty && g_price_per_pixel > 0.0)
      return g_price_per_pixel;

   double price_min = ChartGetDouble(0, CHART_PRICE_MIN);
   double price_max = ChartGetDouble(0, CHART_PRICE_MAX);
   int    height    = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   if(height <= 0 || price_max <= price_min)
   {
      g_price_per_pixel       = 0.0;
      g_price_per_pixel_dirty = true;
      return 0.0;
   }

   g_price_per_pixel       = (price_max - price_min) / (double)height;
   g_price_per_pixel_dirty = false;

   return g_price_per_pixel;
}

int PriceDistanceToPixels(double price_distance)
{
   double ppp = PricePerPixel();
   if(ppp <= 0.0) return 0;
   return (int)MathRound(MathAbs(price_distance) / ppp);
}

double PixelsToPriceDistance(int pixels)
{
   double ppp = PricePerPixel();
   if(ppp <= 0.0) return 0.0;
   return (double)pixels * ppp;
}

bool ChartPointToTimePrice(int px, int py, datetime &t, double &price)
{
   int      subwindow = 0;
   datetime time_out  = 0;
   double   price_out = 0.0;

   if(!ChartXYToTimePrice(0, px, py, subwindow, time_out, price_out)) return false;
   if(subwindow != 0) return false;

   t     = time_out;
   price = price_out;

   return true;
}

datetime BarTimeAtOffset(datetime reference, int bars_forward)
{
   int shift = iBarShift(_Symbol, PERIOD_CURRENT, reference, false);
   if(shift < 0) shift = 0;

   int target = shift - bars_forward;

   if(target >= 0)
   {
      datetime t = iTime(_Symbol, PERIOD_CURRENT, target);
      if(t > 0) return t;
   }

   int period_seconds = PeriodSeconds(PERIOD_CURRENT);
   if(period_seconds <= 0) period_seconds = 60;

   return reference + (datetime)(bars_forward * period_seconds);
}

//+------------------------------------------------------------------+
//| POSICIONES - ESTADO, ICONOS Y ETIQUETAS                          |
//+------------------------------------------------------------------+
int ZoneDisplayNumber(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return 0;

   int number = 0;
   for(int i = 0; i <= idx; i++)
      if(g_positions[i].id >= 0 && !g_positions[i].is_closed) number++;

   if(number == 0) return idx + 1;
   return number;
}

string ZoneStatusIcon(const SVisualPosition &pos)
{
   if(pos.is_closed)      return ICON_CHAR_CLOSED;
   if(pos.is_degenerate)  return ICON_CHAR_DEGENERATE;
   if(pos.is_executed)    return ICON_CHAR_EXECUTED;
   if(pos.order_ticket>0) return ICON_CHAR_PENDING;
   if(pos.is_locked)      return ICON_CHAR_LOCKED;
   return ICON_CHAR_FREE;
}

string ZoneStatusWord(const SVisualPosition &pos)
{
   if(pos.is_closed)       return "cerrada";
   if(pos.is_degenerate)   return "inválida";
   if(pos.is_executed)     return "en mercado";
   if(pos.order_ticket > 0)return "pendiente";
   if(pos.is_locked)       return "bloqueada";
   return "editable";
}

color ZoneEntryColor(const SVisualPosition &pos)
{
   if(pos.is_degenerate) return ColorDanger();
   if(pos.is_executed)   return ColorAccent();
   return InpColorEntry;
}

int ZoneLineWidth(const SVisualPosition &pos, bool is_entry)
{
   int base = (int)MathMax(1, g_line_width);

   if(pos.id == g_selected_id) base += 1;
   if(is_entry && pos.is_executed) base += 1;

   return (int)MathMin(5, base);
}

//+------------------------------------------------------------------+
//| POSICIONES - MÉTRICAS MONETARIAS                                 |
//+------------------------------------------------------------------+
bool ZoneMoneyMetrics(const SVisualPosition &pos, double volume,
                      double &risk_money, double &reward_money, double &rr)
{
   risk_money   = 0.0;
   reward_money = 0.0;
   rr           = 0.0;

   if(volume <= 0.0) return false;

   ENUM_ORDER_TYPE otype = (pos.type == PLANNER_POS_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   double loss = 0.0, gain = 0.0;
   bool ok_loss = ProfitForMove(_Symbol, otype, volume, pos.entry_price, pos.sl_price, loss);
   bool ok_gain = ProfitForMove(_Symbol, otype, volume, pos.entry_price, pos.tp_price, gain);

   if(!ok_loss || !ok_gain)
   {
      double tv = GetTickValueForProfit(_Symbol);
      double ts = GetTickSize(_Symbol);
      if(tv <= 0.0 || ts <= 0.0) return false;

      loss = -MathAbs(pos.entry_price - pos.sl_price) * tv * volume;
      gain =  MathAbs(pos.tp_price    - pos.entry_price) * tv * volume;
   }

   double commission = MathMax(0.0, InpRiskCommissionPerLot) * volume;

   risk_money   = MathAbs(loss) + commission;
   reward_money = MathMax(0.0, gain) - commission;

   if(risk_money > 0.0) rr = reward_money / risk_money;

   return true;
}

string ZoneStatsText(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return "";

   EnsureZoneVolume(idx);

   SVisualPosition pos = g_positions[idx];
   double risk_money, reward_money, rr;

   if(!ZoneMoneyMetrics(pos, pos.qty, risk_money, reward_money, rr))
      return "--";

   return StringFormat("%.2f", rr);
}

string ZoneTooltipText(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return "";

   SVisualPosition pos = g_positions[idx];
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   return StringFormat("Posición #%d (%s) — %s | E %s  TP %s  SL %s",
                       ZoneDisplayNumber(idx),
                       (pos.type == PLANNER_POS_BUY) ? "compra" : "venta",
                       ZoneStatusWord(pos),
                       DoubleToString(pos.entry_price, digits),
                       DoubleToString(pos.tp_price,    digits),
                       DoubleToString(pos.sl_price,    digits));
}

// Devuelve el ratio R:R de la zona formateado como texto ("1:2.4"), o "" si no
// es calculable (zona inválida, volumen nulo o riesgo cero). Se usa tanto en
// la etiqueta de estadísticas como en el tooltip de las zonas.
string ZoneRRText(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return "";

   EnsureZoneVolume(idx);

   SVisualPosition pos = g_positions[idx];
   double risk_money, reward_money, rr;

   if(!ZoneMoneyMetrics(pos, pos.qty, risk_money, reward_money, rr)) return "";
   if(rr <= 0.0) return "";

   return StringFormat("R:R 1:%.1f", rr);
}

//+------------------------------------------------------------------+
//| POSICIONES - CREACIÓN DE OBJETOS GRÁFICOS                        |
//+------------------------------------------------------------------+
void StyleZoneRectangle(string name, color fill, bool selected)
{
   SetObjInt(name, OBJPROP_COLOR,      ApplyTransparency(fill, g_transparency));
   SetObjInt(name, OBJPROP_FILL,       true);
   SetObjInt(name, OBJPROP_BACK,       true);
   SetObjInt(name, OBJPROP_STYLE,      STYLE_SOLID);
   SetObjInt(name, OBJPROP_WIDTH,      1);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_SELECTED,   false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     selected ? 2 : 1);

   // Borde sutil del mismo tono que el relleno: en los bordes la línea del
   // rectángulo se dibuja con opacidad completa, lo que produce un efecto de
   // contorno limpio estilo TradingView sin tapar las velas del interior.
   SetObjInt(name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
}

void StyleZoneLine(string name, color line_color, int width, ENUM_LINE_STYLE style)
{
   SetObjInt(name, OBJPROP_COLOR,      line_color);
   SetObjInt(name, OBJPROP_WIDTH,      width);
   SetObjInt(name, OBJPROP_STYLE,      style);
   SetObjInt(name, OBJPROP_RAY_LEFT,   false);
   SetObjInt(name, OBJPROP_RAY_RIGHT,  false);
   SetObjInt(name, OBJPROP_BACK,       false);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_SELECTED,   false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     10);
}

void StyleZoneText(string name, color text_color, ENUM_ANCHOR_POINT anchor)
{
   SetObjInt(name, OBJPROP_COLOR,      text_color);
   SetObjInt(name, OBJPROP_FONTSIZE,   g_font_size_stats);
   SetObjInt(name, OBJPROP_ANCHOR,     anchor);
   SetObjInt(name, OBJPROP_BACK,       false);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_SELECTED,   false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     11);

   if(ObjectFind(0, name) >= 0)
      ObjectSetString(0, name, OBJPROP_FONT, PANEL_FONT);
}

bool CreatePositionObjects(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return false;

   SVisualPosition pos = g_positions[idx];

   datetime t1 = pos.time_start;
   datetime t2 = pos.time_end;

   string n_rect_tp = ObjectNameForPosition(pos.id, "RECT_TP");
   string n_rect_sl = ObjectNameForPosition(pos.id, "RECT_SL");

   if(ObjectFind(0, n_rect_tp) < 0)
      if(!ObjectCreateChecked(n_rect_tp, OBJ_RECTANGLE, t1, pos.entry_price, t2, pos.tp_price, true))
         return false;

   if(ObjectFind(0, n_rect_sl) < 0)
      if(!ObjectCreateChecked(n_rect_sl, OBJ_RECTANGLE, t1, pos.entry_price, t2, pos.sl_price, true))
         return false;

   string n_line_entry = ObjectNameForPosition(pos.id, "LINE_ENTRY");
   string n_line_tp    = ObjectNameForPosition(pos.id, "LINE_TP");
   string n_line_sl    = ObjectNameForPosition(pos.id, "LINE_SL");

   if(ObjectFind(0, n_line_entry) < 0)
      if(!ObjectCreateChecked(n_line_entry, OBJ_TREND, t1, pos.entry_price, t2, pos.entry_price, true))
         return false;

   if(ObjectFind(0, n_line_tp) < 0)
      if(!ObjectCreateChecked(n_line_tp, OBJ_TREND, t1, pos.tp_price, t2, pos.tp_price, true))
         return false;

   if(ObjectFind(0, n_line_sl) < 0)
      if(!ObjectCreateChecked(n_line_sl, OBJ_TREND, t1, pos.sl_price, t2, pos.sl_price, true))
         return false;

   string n_txt_entry = ObjectNameForPosition(pos.id, "TXT_ENTRY");
   string n_txt_tp    = ObjectNameForPosition(pos.id, "TXT_TP");
   string n_txt_sl    = ObjectNameForPosition(pos.id, "TXT_SL");
   string n_txt_stats = ObjectNameForPosition(pos.id, "TXT_STATS");

   if(ObjectFind(0, n_txt_entry) < 0)
      if(!ObjectCreateChecked(n_txt_entry, OBJ_TEXT, t2, pos.entry_price, 0, 0.0, false))
         return false;

   if(ObjectFind(0, n_txt_tp) < 0)
      if(!ObjectCreateChecked(n_txt_tp, OBJ_TEXT, t2, pos.tp_price, 0, 0.0, false))
         return false;

   if(ObjectFind(0, n_txt_sl) < 0)
      if(!ObjectCreateChecked(n_txt_sl, OBJ_TEXT, t2, pos.sl_price, 0, 0.0, false))
         return false;

   if(ObjectFind(0, n_txt_stats) < 0)
      if(!ObjectCreateChecked(n_txt_stats, OBJ_TEXT, t1, pos.entry_price, 0, 0.0, false))
         return false;

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      string n_line = PartialLineName(pos.id, s + 1);
      string n_text = PartialTextName(pos.id, s + 1);

      double stage_price = PartialStagePrice(pos, s);
      if(stage_price <= 0.0) stage_price = pos.entry_price;

      if(ObjectFind(0, n_line) < 0)
         if(!ObjectCreateChecked(n_line, OBJ_TREND, t1, stage_price, t2, stage_price, true))
            return false;

      if(ObjectFind(0, n_text) < 0)
         if(!ObjectCreateChecked(n_text, OBJ_TEXT, t1, stage_price, 0, 0.0, false))
            return false;
   }

   string handle_suffixes[4] = { "HANDLE_TP_L", "HANDLE_SL_L",
                                  "HANDLE_ENTRY_L", "HANDLE_ENTRY_R" };

   for(int h = 0; h < 4; h++)
   {
      string n_handle = ObjectNameForPosition(pos.id, handle_suffixes[h]);

      if(ObjectFind(0, n_handle) < 0)
         if(!ObjectCreateChecked(n_handle, OBJ_RECTANGLE_LABEL, 0, 0.0, 0, 0.0, false))
            return false;
   }

   return true;
}

void DeletePositionObjects(long id)
{
   SafeObjectDelete(ObjectNameForPosition(id, "RECT_TP"));
   SafeObjectDelete(ObjectNameForPosition(id, "RECT_SL"));
   SafeObjectDelete(ObjectNameForPosition(id, "LINE_ENTRY"));
   SafeObjectDelete(ObjectNameForPosition(id, "LINE_TP"));
   SafeObjectDelete(ObjectNameForPosition(id, "LINE_SL"));
   SafeObjectDelete(ObjectNameForPosition(id, "TXT_ENTRY"));
   SafeObjectDelete(ObjectNameForPosition(id, "TXT_TP"));
   SafeObjectDelete(ObjectNameForPosition(id, "TXT_SL"));
   SafeObjectDelete(ObjectNameForPosition(id, "TXT_STATS"));

   for(int s = 1; s <= PARTIAL_STAGES; s++)
   {
      SafeObjectDelete(PartialLineName(id, s));
      SafeObjectDelete(PartialTextName(id, s));
   }

   string handle_suffixes_del[6] = { "HANDLE_TP_L", "HANDLE_TP_R",
                                      "HANDLE_SL_L", "HANDLE_SL_R",
                                      "HANDLE_ENTRY_L", "HANDLE_ENTRY_R" };

   for(int h = 0; h < 6; h++)
      SafeObjectDelete(ObjectNameForPosition(id, handle_suffixes_del[h]));
}

void DeleteAllZoneObjects()
{
   g_suppress_object_events++;
   ObjectsDeleteAll(0, InpObjectPrefix + "#" + _Symbol + "#");
   g_suppress_object_events--;

   ClearObjectCache();
}

//+------------------------------------------------------------------+
//| POSICIONES - ACTUALIZACIÓN DE OBJETOS                            |
//+------------------------------------------------------------------+
void UpdateZoneRectangle(string name, datetime t1, double p1, datetime t2, double p2,
                         color fill, bool selected, bool visible)
{
   if(!ObjectExistsCached(name)) return;

   if(!visible)
   {
      SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      return;
   }

   SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   ObjectMove(0, name, 0, t1, p1);
   ObjectMove(0, name, 1, t2, p2);

   StyleZoneRectangle(name, fill, selected);
}

void UpdateZoneLine(string name, datetime t1, datetime t2, double price,
                    color line_color, int width, ENUM_LINE_STYLE style, bool visible)
{
   if(!ObjectExistsCached(name)) return;

   if(!visible || price <= 0.0)
   {
      SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      return;
   }

   SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   ObjectMove(0, name, 0, t1, price);
   ObjectMove(0, name, 1, t2, price);

   StyleZoneLine(name, line_color, width, style);
}

void UpdateZoneText(string name, datetime t, double price, string text,
                    color text_color, ENUM_ANCHOR_POINT anchor, bool visible)
{
   if(!ObjectExistsCached(name)) return;

   if(!visible || price <= 0.0 || text == "")
   {
      SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      return;
   }

   SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   ObjectMove(0, name, 0, t, price);
   SetObjText(name, text);
   StyleZoneText(name, text_color, anchor);
}

void StyleZoneHandle(string name, color border_c, color fill_c, int size_px, int zorder)
{
   SetObjInt(name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XSIZE,       size_px);
   SetObjInt(name, OBJPROP_YSIZE,       size_px);
   SetObjInt(name, OBJPROP_BGCOLOR,     fill_c);
   SetObjInt(name, OBJPROP_COLOR,       border_c);
   // BORDER_FLAT en lugar de BORDER_RAISED: el biselado "en relieve" tiene un
   // aspecto anticuado (estilo Windows clásico). Con borde plano de 1px el
   // handle se ve como un punto minimalista, más parecido a TradingView.
   SetObjInt(name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   SetObjInt(name, OBJPROP_WIDTH,       1);
   SetObjInt(name, OBJPROP_BACK,        false);
   SetObjInt(name, OBJPROP_SELECTABLE,  false);
   SetObjInt(name, OBJPROP_SELECTED,    false);
   SetObjInt(name, OBJPROP_HIDDEN,      true);
   SetObjInt(name, OBJPROP_ZORDER,      zorder);

   SetTooltipSafe(name, "\n");
}

void UpdateZoneHandle(string name, datetime t, double price, bool visible,
                      color border_c, color fill_c, int size_px, int zorder)
{
   if(!ObjectExistsCached(name)) return;

   int x = 0, y = 0;
   if(!visible || price <= 0.0 || !ChartTimePriceToXY(0, 0, t, price, x, y))
   {
      SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      return;
   }

   SetObjInt(name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   SetObjInt(name, OBJPROP_XDISTANCE, x - size_px / 2);
   SetObjInt(name, OBJPROP_YDISTANCE, y - size_px / 2);

   StyleZoneHandle(name, border_c, fill_c, size_px, zorder);
}

bool LevelLabelHasRoom(double price_a, double price_b)
{
   if(price_a <= 0.0 || price_b <= 0.0) return true;

   int gap_px    = PriceDistanceToPixels(price_a - price_b);
   int needed_px = (int)MathMax(10, g_font_size_stats + 2 * PANEL_LABEL_HIDE_MARGIN_PX);

   return (gap_px >= needed_px);
}

void UpdatePositionObjects(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return;

   if(ObjectFind(0, ObjectNameForPosition(g_positions[idx].id, "LINE_ENTRY")) < 0)
      if(!CreatePositionObjects(idx)) return;

   EnsureZoneVolume(idx);

   SVisualPosition pos = g_positions[idx];

   string err;
   g_positions[idx].is_degenerate = !ValidateZone(pos, err);
   pos.is_degenerate              = g_positions[idx].is_degenerate;

   bool selected = (pos.id == g_selected_id);
   bool hovered  = (pos.id == g_hover_id);
   bool visible  = true;

   bool show_active = selected || hovered;

   datetime t1 = pos.time_start;
   datetime t2 = pos.time_end;

   if(t2 <= t1) t2 = BarTimeAtOffset(t1, (int)MathMax(1, g_zone_width_bars));

   color entry_color = ZoneEntryColor(pos);
   color tp_color    = InpColorTP;
   color sl_color    = InpColorSL;

   int transparency_backup = g_transparency;
   if(hovered && !selected) g_transparency = (int)MathMax(0, g_transparency - 10);

   UpdateZoneRectangle(ObjectNameForPosition(pos.id, "RECT_TP"),
                       t1, pos.entry_price, t2, pos.tp_price,
                       tp_color, selected, visible && !pos.is_degenerate);

   UpdateZoneRectangle(ObjectNameForPosition(pos.id, "RECT_SL"),
                       t1, pos.entry_price, t2, pos.sl_price,
                       sl_color, selected, visible && !pos.is_degenerate);

   g_transparency = transparency_backup;

   UpdateZoneLine(ObjectNameForPosition(pos.id, "LINE_ENTRY"), t1, t2, pos.entry_price,
                  entry_color, ZoneLineWidth(pos, true), STYLE_DASH, false);

   UpdateZoneLine(ObjectNameForPosition(pos.id, "LINE_TP"), t1, t2, pos.tp_price,
                  tp_color, ZoneLineWidth(pos, false), STYLE_SOLID, false);

   UpdateZoneLine(ObjectNameForPosition(pos.id, "LINE_SL"), t1, t2, pos.sl_price,
                  sl_color, ZoneLineWidth(pos, false), STYLE_SOLID, false);

   bool show_labels = g_show_levels && visible && show_active;

   UpdateZoneText(ObjectNameForPosition(pos.id, "TXT_ENTRY"), t2, pos.entry_price,
                  MainLevelLabelText(pos.entry_price), entry_color, ANCHOR_LEFT, show_labels);

   UpdateZoneText(ObjectNameForPosition(pos.id, "TXT_TP"), t2, pos.tp_price,
                  MainLevelLabelText(pos.tp_price), tp_color, ANCHOR_LEFT,
                  show_labels && LevelLabelHasRoom(pos.tp_price, pos.entry_price));

   UpdateZoneText(ObjectNameForPosition(pos.id, "TXT_SL"), t2, pos.sl_price,
                  MainLevelLabelText(pos.sl_price), sl_color, ANCHOR_LEFT,
                  show_labels && LevelLabelHasRoom(pos.sl_price, pos.entry_price));

   double stats_anchor_price = pos.entry_price - PixelsToPriceDistance(STATS_LABEL_GAP_PX);
   if(stats_anchor_price <= 0.0) stats_anchor_price = pos.entry_price;

   // Etiqueta compacta "R:R 1:x.x" bajo la entrada (evita solaparse con las
   // etiquetas de nivel, que se anclan a la derecha del borde derecho).
   string rr_text = ZoneRRText(idx);

   UpdateZoneText(ObjectNameForPosition(pos.id, "TXT_STATS"), t2, stats_anchor_price,
                  "  " + rr_text, InpColorStats, ANCHOR_LEFT_UPPER,
                  show_labels && rr_text != "");

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      string n_line = PartialLineName(pos.id, s + 1);
      string n_text = PartialTextName(pos.id, s + 1);

      bool   stage_on    = PartialStageActive(pos, s) && !pos.is_degenerate;
      double stage_price = PartialStagePrice(pos, s);

      bool usable = stage_on && PartialStagePriceUsable(pos, s);
      color c     = usable ? ColorPartialLevel() : ColorWarning();

      UpdateZoneLine(n_line, t1, t2, stage_price, c,
                     (int)MathMax(1, g_line_width), STYLE_DOT, stage_on);

      bool label_ok = stage_on && show_labels &&
                      LevelLabelHasRoom(stage_price, pos.entry_price) &&
                      LevelLabelHasRoom(stage_price, pos.tp_price);

      UpdateZoneText(n_text, t2, stage_price, PartialStageLabelText(pos, s),
                     c, ANCHOR_RIGHT, label_ok);
   }

   SetTooltipSafe(ObjectNameForPosition(pos.id, "LINE_ENTRY"), "\n");

   // Tooltip informativo en las zonas: al pasar el ratón se ven los niveles y
   // el R:R sin necesidad de seleccionar la posición (antes estaba vacío).
   string zone_tooltip = ZoneTooltipText(idx);
   if(zone_tooltip != "")
      SetTooltipSafe(ObjectNameForPosition(pos.id, "RECT_TP"), zone_tooltip);
   else
      SetTooltipSafe(ObjectNameForPosition(pos.id, "RECT_TP"), "\n");
   SetTooltipSafe(ObjectNameForPosition(pos.id, "RECT_SL"), "\n");

   bool show_handles = show_active && !pos.is_degenerate && !pos.is_closed;

   bool entry_locked_draft = pos.is_locked && !pos.is_executed && !pos.is_closed &&
                             pos.order_ticket == 0;

   bool show_entry_handle_left  = show_handles && !entry_locked_draft;
   bool show_entry_handle_right = show_handles && (!pos.is_locked || entry_locked_draft);

   const int HANDLE_ZORDER = 15;
   // Handle algo más compacto: aspecto minimalista tipo TradingView.
   const int HANDLE_SIZE   = 10;

   // Color de relleno del handle según su función (los handles comparten el
   // mismo z-order, así que el color es la única señal visual fiable):
   // verde/rojo para niveles TP/SL y acento azul para la línea de entrada.
   color tp_handle_fill = ApplyTransparency(InpColorTP, 25);
   color sl_handle_fill = ApplyTransparency(InpColorSL, 25);

   UpdateZoneHandle(ObjectNameForPosition(pos.id, "HANDLE_TP_L"), t1, pos.tp_price,
                    show_handles, ColorAccent(), tp_handle_fill,
                    HANDLE_SIZE, HANDLE_ZORDER);

   UpdateZoneHandle(ObjectNameForPosition(pos.id, "HANDLE_SL_L"), t1, pos.sl_price,
                    show_handles, ColorAccent(), sl_handle_fill,
                    HANDLE_SIZE, HANDLE_ZORDER);

   SafeObjectDelete(ObjectNameForPosition(pos.id, "HANDLE_TP_R"));
   SafeObjectDelete(ObjectNameForPosition(pos.id, "HANDLE_SL_R"));

   UpdateZoneHandle(ObjectNameForPosition(pos.id, "HANDLE_ENTRY_L"), t1, pos.entry_price,
                    show_entry_handle_left, ColorAccent(), ColorBackground(),
                    HANDLE_SIZE, HANDLE_ZORDER);
   UpdateZoneHandle(ObjectNameForPosition(pos.id, "HANDLE_ENTRY_R"), t2, pos.entry_price,
                    show_entry_handle_right, ColorAccent(), entry_color,
                    HANDLE_SIZE, HANDLE_ZORDER);
}

void RebuildAllZoneObjects()
{
   if(IsSilentTesterMode()) return; // sin objetos gráficos en tester no-visual

   DeleteAllZoneObjects();

   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      if(g_positions[i].id < 0) continue;
      if(!CreatePositionObjects(i)) continue;
      UpdatePositionObjects(i);
   }

   g_pending_zone_rebuild = false;
   RequestRedraw();
}

void RecalculateAllPositions()
{
   InvalidatePricePerPixel();

   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      if(g_positions[i].id < 0) continue;
      InvalidateZoneVolume(i);
      UpdatePositionObjects(i);
   }

   MarkPanelDirty();
   RequestRedraw();
}

//+------------------------------------------------------------------+
//| SINCRONIZACIÓN DE POSICIONES BLOQUEADAS CON EL PRECIO            |
//+------------------------------------------------------------------+
void SynchronizeLockedDraftZones()
{
   MqlTick tick;
   string  reason;
   if(!GetTradableTick(_Symbol, tick, reason)) return;

   static ulong s_next_volume_recalc_ms = 0;
   ulong now_ms = NowMs();
   bool  allow_volume_recalc = (now_ms >= s_next_volume_recalc_ms);
   if(allow_volume_recalc)
      s_next_volume_recalc_ms = now_ms + ZONE_VOLUME_RECALC_THROTTLE_MS;

   double tick_size = GetTickSize(_Symbol);
   double price_move_threshold = (tick_size > 0.0) ? (tick_size * 0.5) : 0.0;

   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      SVisualPosition pos = g_positions[i];

      if(pos.id < 0) continue;

      if(!pos.is_locked || pos.is_executed || pos.is_closed || pos.order_ticket > 0)
         continue;

      double anchor = pos.use_ask_anchor ? tick.ask : tick.bid;
      anchor = NormalizeToTick(anchor);
      if(anchor <= 0.0) continue;

      double delta = anchor - pos.entry_price;

      bool moved_price = (MathAbs(delta) >= price_move_threshold);

      datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
      bool moved_time = (current_bar > 0 && g_positions[i].time_start != current_bar);
      if(moved_time)
      {
         g_positions[i].time_start = current_bar;
         if(g_positions[i].time_end <= current_bar)
            g_positions[i].time_end = BarTimeAtOffset(current_bar,
                                                       (int)MathMax(1, g_zone_width_bars));
      }

      if(!moved_price && !moved_time) continue;

      if(moved_price)
      {
         g_positions[i].entry_price = anchor;
         g_positions[i].tp_price    = NormalizeToTick(pos.tp_price + delta);
         g_positions[i].sl_price    = NormalizeToTick(pos.sl_price + delta);

         for(int s = 0; s < PARTIAL_STAGES; s++)
         {
            if(g_positions[i].partial_is_manual[s])
               g_positions[i].partial_manual_price[s] =
                  NormalizeToTick(pos.partial_manual_price[s] + delta);
         }

         if(allow_volume_recalc)
            InvalidateZoneVolume(i);
      }

      UpdatePositionObjects(i);

      RequestRedraw();
   }
}

void RequestRedraw()
{
   g_needs_redraw = true;
}

void RequestDragRedraw()
{
   static ulong last_ms = 0;

   ulong now = NowMs();
   if(now - last_ms < (ulong)DRAG_REDRAW_THROTTLE_MS) return;

   last_ms = now;
   ChartRedraw(0);
   g_needs_redraw = false;
}


//| POSICIONES - ALTA, SELECCIÓN Y BAJA                              |
//+------------------------------------------------------------------+
void ResetZoneStruct(SVisualPosition &p)
{
   p.id             = -1;
   p.symbol         = _Symbol;
   p.type           = PLANNER_POS_BUY;
   p.entry_price    = 0.0;
   p.tp_price       = 0.0;
   p.sl_price       = 0.0;
   p.time_start     = 0;
   p.time_end       = 0;
   p.closed_at      = 0;
   p.qty            = 0.0;
   p.qty_valid      = false;
   p.is_locked      = true;
   p.use_ask_anchor = true;
   p.is_degenerate  = false;
   p.is_executed    = false;
   p.is_closed      = false;
   p.ticket         = 0;
   p.order_ticket   = 0;

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      p.partial_is_manual[s]    = false;
      p.partial_manual_price[s] = 0.0;
   }
}

void SelectZone(long id)
{
   if(g_selected_id == id) return;

   long previous  = g_selected_id;
   g_selected_id  = id;

   int prev_idx = FindPositionById(previous);
   if(prev_idx >= 0) UpdatePositionObjects(prev_idx);

   int new_idx = FindPositionById(id);
   if(new_idx >= 0) UpdatePositionObjects(new_idx);

   RefreshPartialCheckboxes();
   MarkPanelDirty();
   RequestRedraw();
}

long CreateVisualPosition(ENUM_PLANNER_POS_TYPE type, double anchor_price, datetime anchor_time)
{
   MqlTick tick;
   string  quote_reason;

   if(anchor_price <= 0.0)
   {
      if(!GetTradableTick(_Symbol, tick, quote_reason))
      {
         SetPanelStatus("No se pudo crear la posición: " + quote_reason, true);
         return -1;
      }

      anchor_price = (type == PLANNER_POS_BUY) ? tick.ask : tick.bid;
   }

   if(anchor_time <= 0) anchor_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(anchor_time <= 0) anchor_time = TimeCurrent();

   double tick_size = GetTickSize(_Symbol);
   if(tick_size <= 0.0)
   {
      SetPanelStatus("El símbolo no reporta un tamaño de tick válido.", true);
      return -1;
   }

   double tp_distance = (double)MathMax(1, g_tp_ticks) * tick_size;
   double sl_distance = (double)MathMax(1, g_sl_ticks) * tick_size;

   SVisualPosition p;
   ResetZoneStruct(p);

   p.id             = ++g_position_counter;
   p.type           = type;
   p.use_ask_anchor = (type == PLANNER_POS_BUY);
   p.entry_price    = NormalizeToTick(anchor_price);

   if(type == PLANNER_POS_BUY)
   {
      p.tp_price = NormalizeToTick(p.entry_price + tp_distance);
      p.sl_price = NormalizeToTick(p.entry_price - sl_distance);
   }
   else
   {
      p.tp_price = NormalizeToTick(p.entry_price - tp_distance);
      p.sl_price = NormalizeToTick(p.entry_price + sl_distance);
   }

   p.time_start = anchor_time;
   p.time_end   = BarTimeAtOffset(anchor_time, (int)MathMax(1, g_zone_width_bars));

   int n = ArraySize(g_positions);
   int actual_size = n;

   for(int i = 0; i < n; i++)
      if(g_positions[i].id < 0) { actual_size = i; break; }

   if(actual_size == n)
   {
      int old_total = ArraySize(g_positions);
      int new_total = EnsureArrayCapacity(g_positions, n + 1);
      if(new_total < n + 1)
      {
         PrintFormat("%s: ERROR — no se pudo ampliar el array de posiciones.", APP_NAME);
         g_position_counter--;
         return -1;
      }

      for(int g = old_total; g < new_total; g++)
         if(g != n) ResetZoneStruct(g_positions[g]);

      actual_size = n;
   }

   g_positions[actual_size] = p;

   if(!CreatePositionObjects(actual_size))
   {
      ResetZoneStruct(g_positions[actual_size]);
      g_position_counter--;
      SetPanelStatus("No se pudieron crear los objetos gráficos de la posición.", true);
      return -1;
   }

   InvalidateZoneVolume(actual_size);
   UpdatePositionObjects(actual_size);

   g_selected_id = p.id;

   RefreshPartialCheckboxes();
   MarkPanelDirty();
   MarkStateDirty();
   RequestRedraw();

   return p.id;
}

bool RemoveVisualPosition(long id, bool force)
{
   int idx = FindPositionById(id);
   if(idx < 0) return false;

   if(!force)
   {
      if(g_positions[idx].is_executed && g_positions[idx].ticket > 0 &&
         PositionSelectByTicket(g_positions[idx].ticket))
      {
         SetPanelStatus("Esta posición ya tiene una operación viva en mercado; ciérrela primero.", true);
         return false;
      }

      if(ZoneHasLivePendingOrder(idx))
      {
         if(!CancelPendingOrder(g_positions[idx].order_ticket, "eliminación de posición"))
         {
            SetPanelStatus("No se pudo cancelar la orden pendiente asociada a la posición.", true);
            return false;
         }
      }
   }

   DeletePositionObjects(id);

   int last = ArraySize(g_positions) - 1;
   for(int i = idx; i < last; i++)
      g_positions[i] = g_positions[i + 1];

   ArrayResize(g_positions, last);

   if(g_selected_id == id) g_selected_id = -1;
   if(g_hover_id    == id) g_hover_id    = -1;
   if(g_drag_id     == id) { g_drag_mode = DRAG_NONE; g_drag_id = -1; }

   RefreshPartialCheckboxes();
   MarkPanelDirty();
   MarkStateDirty();
   RequestRedraw();

   return true;
}

void MarkZoneClosed(int idx)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return;
   if(g_positions[idx].is_closed) return;

   g_positions[idx].is_closed    = true;
   g_positions[idx].is_executed  = false;
   g_positions[idx].closed_at    = TimeCurrent();
   g_positions[idx].order_ticket = 0;
   g_positions[idx].is_locked    = true;

   UpdatePositionObjects(idx);
   PurgeOldClosedZones();

   MarkPanelDirty();
   MarkStateDirty();
   RequestRedraw();
}

void PurgeOldClosedZones()
{
   int limit = (int)MathMax(0, g_closed_zone_limit);

   while(true)
   {
      int      closed_count = 0;
      int      oldest_idx   = -1;
      datetime oldest_time  = 0;

      for(int i = 0; i < ArraySize(g_positions); i++)
      {
         if(g_positions[i].id < 0) continue;
         if(!g_positions[i].is_closed) continue;

         closed_count++;

         datetime stamp = g_positions[i].closed_at;
         if(stamp <= 0) stamp = g_positions[i].time_start;

         if(oldest_idx < 0 || stamp < oldest_time)
         {
            oldest_idx  = i;
            oldest_time = stamp;
         }
      }

      if(closed_count <= limit || oldest_idx < 0) break;
      if(!RemoveVisualPosition(g_positions[oldest_idx].id, true)) break;
   }
}

//+------------------------------------------------------------------+
//| POLÍTICA DE CUENTA (NETTING / HEDGING / MODO DEGRADADO)          |
//+------------------------------------------------------------------+
void SetDegradedMode(bool active, string reason)
{
   if(g_degraded_mode == active && g_degraded_reason == reason) return;

   g_degraded_mode   = active;
   g_degraded_reason = active ? reason : "";

   if(active)
      PrintFormat("%s: MODO DEGRADADO — %s", APP_NAME, reason);
   else
      PrintFormat("%s: modo degradado desactivado.", APP_NAME);

   MarkPanelDirty();
}

void ApplyAccountModePolicy()
{
   g_exec_allowed = true;
   g_mgmt_allowed = true;

   string reason = "";

   if(!g_is_primary_instance)
   {
      g_exec_allowed = false;
      g_mgmt_allowed = false;
      reason = "instancia en modo observador (otra instancia tiene el bloqueo de esta cuenta/símbolo)";
      SetDegradedMode(true, reason);
      SetPanelStatus("Modo observador: sin ejecución ni gestión automática.", true);
      return;
   }

   if(!IsHedgingAccount())
   {
      if(!InpAllowNettingTrading)
      {
         g_exec_allowed = false;
         reason = "cuenta NETTING y InpAllowNettingTrading = false: la ejecución está desactivada";
      }

      if(!InpAllowNettingManagement)
      {
         g_mgmt_allowed = false;
         if(reason != "") reason += "; ";
         reason += "gestión automática desactivada en cuenta NETTING " +
                   "(InpAllowNettingManagement = false)";
      }
      else if(g_mgmt_allowed)
      {
         if(reason != "") reason += "; ";
         reason += "cuenta NETTING: las posiciones se agregan por símbolo, " +
                   "los parciales y el break-even pueden afectar a volumen ajeno al EA";
      }
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      g_exec_allowed = false;
      g_mgmt_allowed = false;
      if(reason != "") reason += "; ";
      reason += "el trading algorítmico está desactivado en el terminal";
   }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      g_exec_allowed = false;
      g_mgmt_allowed = false;
      if(reason != "") reason += "; ";
      reason += "el EA no tiene permiso de trading (revise las propiedades del experto)";
   }

   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      g_exec_allowed = false;
      g_mgmt_allowed = false;
      if(reason != "") reason += "; ";
      reason += "el servidor no permite operar con expertos en esta cuenta";
   }

   if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
   {
      g_exec_allowed = false;
      if(reason != "") reason += "; ";
      reason += _Symbol + " no admite operaciones en este momento";
   }

   SetDegradedMode(reason != "", reason);
}

//+------------------------------------------------------------------+
//| CONFIGURACIÓN DE GESTIÓN - VALIDACIÓN Y BANDERAS                 |
//+------------------------------------------------------------------+
void RecomputeManagementFlags()
{

   double total_pct = 0.0;
   int    active    = 0;

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      g_partial_mult[s] = MathMax(0.0, MathMin(1000.0, g_partial_mult[s]));
      g_partial_pct[s]  = MathMax(0.0, MathMin(100.0,  g_partial_pct[s]));

      bool usable = (g_partial_pct[s] > 0.0 && g_partial_mult[s] > 0.0);

      if(g_partial_enabled[s] && !usable)
      {
         g_partial_enabled[s] = false;
      }

      if(!g_partial_enabled[s]) continue;

      active++;
      total_pct += g_partial_pct[s];
   }

   if(total_pct > 100.0 + 1e-6)
   {
      PrintFormat("%s: AVISO — los porcentajes de parciales suman %.1f%% (> 100%%). " +
                  "El último tramo se recortará al volumen disponible.", APP_NAME, total_pct);
   }

   for(int i = 1; i < PARTIAL_STAGES; i++)
   {
      if(!g_partial_enabled[i] || !g_partial_enabled[i - 1]) continue;
      if(g_partial_mult[i] > g_partial_mult[i - 1]) continue;

      PrintFormat("%s: AVISO — el múltiplo del parcial %d (%.1f%%) no es mayor que el del " +
                  "parcial %d (%.1f%%); los tramos deben ser crecientes.",
                  APP_NAME, i + 1, g_partial_mult[i], i, g_partial_mult[i - 1]);
   }

   if(g_enable_partials && active == 0)
      g_enable_partials = false;

   if(g_enable_breakeven && !g_enable_partials)
   {
      if(!g_be_stage_warned)
      {
         PrintFormat("%s: AVISO — el break-even está configurado tras un parcial, pero no hay " +
                     "parciales activos: se usará únicamente el umbral de %.2fR.",
                     APP_NAME, g_be_start_r);
         g_be_stage_warned = true;
      }
   }

   if(g_enable_trailing && InpTrailingMethod == TRAIL_ATR && g_trail_atr_failed)
   {
      PrintFormat("%s: AVISO — el ATR de trailing no está disponible; se usará trailing fijo.",
                  APP_NAME);
   }

   RefreshManagementToggles();
   RefreshPartialCheckboxes();
   MarkPanelDirty();
}

//+------------------------------------------------------------------+
//| GESTIÓN - CONGELACIÓN DEL PLAN AL EJECUTAR                       |
//+------------------------------------------------------------------+
void ResetManagementRecord(SPositionManagement &m)
{
   m.ticket          = 0;
   m.order_type      = -1;
   m.volume_original = 0.0;
   m.entry_price     = 0.0;
   m.risk_distance   = 0.0;
   m.target_distance = 0.0;

   m.plan_partials_on = false;

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      m.plan_stage_active[s]       = false;
      m.plan_stage_price[s]        = 0.0;
      m.plan_stage_pct[s]          = 0.0;
      m.partial_resolved[s]        = false;
      m.partial_executed[s]        = false;
      m.partial_executed_volume[s] = 0.0;
      m.partial_skipped_warned[s]  = false;
      m.partial_fail_count[s]      = 0;
   }

   m.plan_be_on           = false;
   m.plan_be_stage        = 1;
   m.plan_be_offset_ticks = 0;
   m.plan_be_start_r      = 1.0;
   m.plan_be_cover_costs  = false;

   m.plan_trail_on         = false;
   m.plan_trail_method     = TRAIL_NONE;
   m.plan_trail_ticks      = 0;
   m.plan_trail_step_ticks = 0;
   m.plan_trail_start_r    = 1.0;
   m.plan_trail_atr_mult   = 0.0;

   m.breakeven_done = false;
   m.trailing_active = false;
   m.foreign_warned  = false;

   m.intended_sl    = 0.0;
   m.intended_tp    = 0.0;
   m.levels_pending = false;
   m.level_attempts = 0;
   m.level_alerted  = false;
   m.emergency_close_fail_count = 0;

   m.next_attempt_ms  = 0;
   m.fail_count       = 0;
   m.failure_reported = false;
}

void FreezeManagementPlan(SPositionManagement &m, const SVisualPosition &pos)
{
   bool is_long = (pos.type == PLANNER_POS_BUY);

   double sl_ref = pos.sl_price;
   double tp_ref = pos.tp_price;

   if(InpKeepDistancesOnFillShift)
   {
      double fill_shift = m.entry_price - pos.entry_price;
      if(MathAbs(fill_shift) > 1e-12)
      {
         sl_ref = NormalizeToTick(pos.sl_price + fill_shift);
         tp_ref = NormalizeToTick(pos.tp_price + fill_shift);

         LogExecution(StringFormat(
            "Entrada desplazada %s respecto al plan (%s -> %s); SL/TP ajustados %s para " +
            "conservar la distancia planificada.",
            DoubleToString(fill_shift, _Digits),
            DoubleToString(pos.entry_price, _Digits), DoubleToString(m.entry_price, _Digits),
            DoubleToString(fill_shift, _Digits)), false);
      }
   }

   m.risk_distance   = MathAbs(m.entry_price - sl_ref);
   m.target_distance = MathAbs(tp_ref  - m.entry_price);

   m.plan_partials_on = (g_enable_partials && g_mgmt_allowed);

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      bool   active = PartialStageActive(pos, s);
      double price  = PartialStagePrice(pos, s);
      double pct    = PartialStagePercent(pos, s);

      if(pos.partial_is_manual[s])
      {
         price = pos.partial_manual_price[s];
      }
      else if(m.target_distance > 0.0)
      {
         double fraction = g_partial_mult[s] / 100.0;
         price = is_long ? (m.entry_price + fraction * m.target_distance)
                         : (m.entry_price - fraction * m.target_distance);
      }

      price = NormalizeToTick(price);

      bool usable = active && price > 0.0 && pct > 0.0 &&
                    (is_long ? (price > m.entry_price) : (price < m.entry_price));

      m.plan_stage_active[s] = usable;
      m.plan_stage_price[s]  = usable ? price : 0.0;
      m.plan_stage_pct[s]    = usable ? pct   : 0.0;

      if(active && !usable)
         PrintFormat("%s: parcial %d descartado en el ticket %I64u (precio %s no válido " +
                     "respecto a la entrada %s).",
                     APP_NAME, s + 1, m.ticket,
                     DoubleToString(price, _Digits), DoubleToString(m.entry_price, _Digits));
   }

   m.plan_be_on           = (g_enable_breakeven && g_mgmt_allowed);
   m.plan_be_stage        = (int)InpBreakEvenTrigger;
   m.plan_be_offset_ticks = (int)MathMax(0, g_be_offset_ticks);
   m.plan_be_start_r      = MathMax(0.0, g_be_start_r);
   m.plan_be_cover_costs  = InpBreakEvenCoverCosts;

   m.plan_trail_on         = (g_enable_trailing && g_mgmt_allowed);
   m.plan_trail_method     = (int)InpTrailingMethod;
   m.plan_trail_ticks      = (int)MathMax(1, g_trailing_ticks);
   m.plan_trail_step_ticks = (int)MathMax(1, g_trailing_step_ticks);
   m.plan_trail_start_r    = MathMax(0.0, g_trailing_start_r);
   m.plan_trail_atr_mult   = MathMax(0.1, g_trailing_atr_multiplier);

   if(m.plan_trail_method == TRAIL_ATR && g_trail_atr_failed)
      m.plan_trail_method = TRAIL_FIXED;

   m.intended_sl = NormalizeToTick(sl_ref);
   m.intended_tp = NormalizeToTick(tp_ref);
}

int RegisterPositionManagement(ulong ticket, int zone_idx)
{
   if(ticket == 0) return -1;
   if(zone_idx < 0 || zone_idx >= ArraySize(g_positions)) return -1;
   if(!PositionSelectByTicket(ticket)) return -1;

   int existing = FindManagementIndex(ticket);
   if(existing >= 0) return existing;

   SPositionManagement m;
   ResetManagementRecord(m);

   m.ticket          = ticket;
   m.order_type      = PositionGetInteger(POSITION_TYPE);
   m.volume_original = PositionGetDouble(POSITION_VOLUME);
   m.entry_price     = PositionGetDouble(POSITION_PRICE_OPEN);

   if(m.volume_original <= 0.0 || m.entry_price <= 0.0)
   {
      PrintFormat("%s: no se pudo registrar la gestión del ticket %I64u (datos incompletos).",
                  APP_NAME, ticket);
      return -1;
   }

   FreezeManagementPlan(m, g_positions[zone_idx]);

   double live_sl = PositionGetDouble(POSITION_SL);
   double live_tp = PositionGetDouble(POSITION_TP);

   m.levels_pending = (InpVerifyProtectiveLevels &&
                       (MathAbs(live_sl - m.intended_sl) > GetTickSize(_Symbol) / 2.0 ||
                        MathAbs(live_tp - m.intended_tp) > GetTickSize(_Symbol) / 2.0));

   int n = ArraySize(g_management);
   if(EnsureArrayCapacity(g_management, n + 1) < n + 1)
   {
      PrintFormat("%s: ERROR — no se pudo ampliar el registro de gestión.", APP_NAME);
      return -1;
   }

   g_management[n] = m;

   g_positions[zone_idx].ticket      = ticket;
   g_positions[zone_idx].is_executed = true;
   g_positions[zone_idx].is_locked   = true;
   g_positions[zone_idx].qty_valid   = false;

   LogExecution(StringFormat("Gestión registrada para el ticket %I64u: %s lotes a %s " +
                             "(parciales %s, BE %s, trailing %s).",
                             ticket,
                             DoubleToString(m.volume_original, VolumeDecimalsFromStep(_Symbol)),
                             DoubleToString(m.entry_price, _Digits),
                             m.plan_partials_on ? "ON" : "OFF",
                             m.plan_be_on       ? "ON" : "OFF",
                             m.plan_trail_on    ? "ON" : "OFF"),
                false);

   UpdatePositionObjects(zone_idx);
   MarkStateDirty();
   MarkPanelDirty();

   return n;
}

void RemoveManagementIndex(int idx)
{
   int total = ArraySize(g_management);
   if(idx < 0 || idx >= total) return;

   if(idx < total - 1)
      g_management[idx] = g_management[total - 1];

   ArrayResize(g_management, total - 1);
   MarkStateDirty();
}

bool PartialStageReached(int mgmt_idx, int stage)
{
   if(mgmt_idx < 0 || mgmt_idx >= ArraySize(g_management)) return false;
   if(stage < 0 || stage >= PARTIAL_STAGES) return false;
   if(!g_management[mgmt_idx].plan_stage_active[stage]) return false;

   double target = g_management[mgmt_idx].plan_stage_price[stage];
   if(target <= 0.0) return false;

   MqlTick tick;
   string  reason;
   if(!GetTradableTick(_Symbol, tick, reason)) return false;

   bool is_long = (g_management[mgmt_idx].order_type == POSITION_TYPE_BUY);

   return is_long ? (tick.bid >= target) : (tick.ask <= target);
}

void PruneClosedManagementRecords()
{
   for(int i = ArraySize(g_management) - 1; i >= 0; i--)
   {
      ulong ticket = g_management[i].ticket;
      if(PositionSelectByTicket(ticket)) continue;

      int zone_idx = FindPositionByPositionTicket(ticket);
      if(zone_idx >= 0) MarkZoneClosed(zone_idx);

      LogExecution(StringFormat("El ticket %I64u ya no existe; se retira de la gestión activa.",
                                ticket), false);

      RemoveManagementIndex(i);
   }
}

//+------------------------------------------------------------------+
//| ==== PARTE 3/4 ====                                              |
//| Panel principal, panel de configuración, eventos de ratón y      |
//| teclado, arrastre de posiciones y edición de campos.             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| PROTOTIPOS DEFINIDOS EN LA PARTE 4                               |
//+------------------------------------------------------------------+
bool CloseZoneVolume(int idx, double percent, string context);
void RequestFlattenAll(string reason);
bool ModifyPositionLevels(ulong ticket, double sl, double tp, string context);
bool CancelAllPendingOrders(string context);
void ForceLimitRecheck();

//+------------------------------------------------------------------+
//| PANEL - REGISTRO DE OBJETOS Y CACHÉ DE MAQUETACIÓN               |
//+------------------------------------------------------------------+
void CachePanelLayout(string include_prefix, string exclude_prefix, int anchor_x, int anchor_y,
                      string &out_names[], int &out_rel_x[], int &out_rel_y[], int &out_count)
{
   out_count = 0;
   ArrayResize(out_names, 0);
   ArrayResize(out_rel_x, 0);
   ArrayResize(out_rel_y, 0);

   int total = ObjectsTotal(0, -1, -1);

   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, include_prefix) != 0) continue;
      if(exclude_prefix != "" && StringFind(name, exclude_prefix) == 0) continue;

      int n = out_count;
      if(ArrayResize(out_names, n + 1) != n + 1) return;
      if(ArrayResize(out_rel_x, n + 1) != n + 1) return;
      if(ArrayResize(out_rel_y, n + 1) != n + 1) return;

      out_names[n] = name;
      out_rel_x[n] = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE) - anchor_x;
      out_rel_y[n] = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE) - anchor_y;

      out_count = n + 1;
   }
}

void ApplyPanelLayout(string &names[], int &rel_x[], int &rel_y[], int count,
                      int anchor_x, int anchor_y)
{
   for(int i = 0; i < count; i++)
   {
      ObjectSetInteger(0, names[i], OBJPROP_XDISTANCE, anchor_x + rel_x[i]);
      ObjectSetInteger(0, names[i], OBJPROP_YDISTANCE, anchor_y + rel_y[i]);
   }
}

void RaisePanelCanvasToFront()
{
   for(int i = 0; i < g_panel_obj_count; i++)
   {
      if(ObjectFind(0, g_panel_obj_names[i]) < 0) continue;

      long z = ObjectGetInteger(0, g_panel_obj_names[i], OBJPROP_ZORDER);
      if(z < PANEL_ZORDER_BOOST)
         SetObjInt(g_panel_obj_names[i], OBJPROP_ZORDER, z + PANEL_ZORDER_BOOST);
   }

   for(int j = 0; j < g_settings_obj_count; j++)
   {
      if(ObjectFind(0, g_settings_obj_names[j]) < 0) continue;

      long z = ObjectGetInteger(0, g_settings_obj_names[j], OBJPROP_ZORDER);
      if(z < 2 * PANEL_ZORDER_BOOST)
         SetObjInt(g_settings_obj_names[j], OBJPROP_ZORDER, z + 2 * PANEL_ZORDER_BOOST);
   }
}

//+------------------------------------------------------------------+
//| PANEL - PRIMITIVAS DE CONSTRUCCIÓN                               |
//+------------------------------------------------------------------+
bool PanelRect(string suffix, int x, int y, int w, int h, color bg, color border, int zorder)
{
   string name = ObjectNameForPanel(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_RECTANGLE_LABEL, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,  x);
   SetObjInt(name, OBJPROP_YDISTANCE,  y);
   SetObjInt(name, OBJPROP_XSIZE,      w);
   SetObjInt(name, OBJPROP_YSIZE,      h);
   SetObjInt(name, OBJPROP_BGCOLOR,    bg);
   SetObjInt(name, OBJPROP_COLOR,      border);
   SetObjInt(name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   SetObjInt(name, OBJPROP_WIDTH,      1);
   SetObjInt(name, OBJPROP_BACK,       false);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_SELECTED,   false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     zorder);

   return true;
}

bool PanelLabel(string suffix, int x, int y, string text, color text_color, int font_pt,
                bool bold, ENUM_ANCHOR_POINT anchor)
{
   string name = ObjectNameForPanel(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_LABEL, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,  x);
   SetObjInt(name, OBJPROP_YDISTANCE,  y);
   SetObjInt(name, OBJPROP_ANCHOR,     anchor);
   SetObjInt(name, OBJPROP_COLOR,      text_color);
   SetObjInt(name, OBJPROP_FONTSIZE,   font_pt);
   SetObjInt(name, OBJPROP_BACK,       false);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_SELECTED,   false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     20);

   ObjectSetString(0, name, OBJPROP_FONT, bold ? PANEL_FONT_BOLD : PANEL_FONT);
   SetObjText(name, text);

   return true;
}

bool PanelButton(string suffix, int x, int y, int w, int h, string text,
                 color bg, color border, color text_color, int font_pt, bool bold)
{
   string name = ObjectNameForPanel(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_BUTTON, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,  x);
   SetObjInt(name, OBJPROP_YDISTANCE,  y);
   SetObjInt(name, OBJPROP_XSIZE,      w);
   SetObjInt(name, OBJPROP_YSIZE,      h);
   SetObjInt(name, OBJPROP_BGCOLOR,    bg);
   SetObjInt(name, OBJPROP_BORDER_COLOR, border);
   SetObjInt(name, OBJPROP_COLOR,      text_color);
   SetObjInt(name, OBJPROP_FONTSIZE,   font_pt);
   SetObjInt(name, OBJPROP_STATE,      false);
   SetObjInt(name, OBJPROP_BACK,       false);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_SELECTED,   false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     30);

   ObjectSetString(0, name, OBJPROP_FONT, bold ? PANEL_FONT_BOLD : PANEL_FONT);
   SetObjText(name, text);

   return true;
}

bool g_icon_font_usable = true;

bool DetectIconFontUsable()
{
   TextSetFont(ICON_FONT, -100);

   uint w = 0, h = 0;
   if(!TextGetSize(ICON_CHAR_GEAR, w, h)) return false;

   return (w > 0 && h > 0);
}

bool PanelIconButton(string suffix, int x, int y, int w, int h, string glyph,
                     color bg, color border, color glyph_color, int font_pt,
                     string ascii_fallback = "")
{
   string effective_glyph = (g_icon_font_usable || ascii_fallback == "") ? glyph : ascii_fallback;

   if(!PanelButton(suffix, x, y, w, h, effective_glyph, bg, border, glyph_color, font_pt, false))
      return false;

   if(g_icon_font_usable)
      ObjectSetString(0, ObjectNameForPanel(suffix), OBJPROP_FONT, ICON_FONT);

   return true;
}

bool PanelEdit(string suffix, int x, int y, int w, int h, string text, bool enabled,
               int font_pt, ENUM_ALIGN_MODE align)
{
   string name = ObjectNameForPanel(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_EDIT, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,  x);
   SetObjInt(name, OBJPROP_YDISTANCE,  y);
   SetObjInt(name, OBJPROP_XSIZE,      w);
   SetObjInt(name, OBJPROP_YSIZE,      h);
   SetObjInt(name, OBJPROP_BGCOLOR,    ColorEditBackground(enabled));
   SetObjInt(name, OBJPROP_BORDER_COLOR, ColorEditBorder(enabled));
   SetObjInt(name, OBJPROP_COLOR,      ColorEditText(enabled));
   SetObjInt(name, OBJPROP_FONTSIZE,   font_pt);
   SetObjInt(name, OBJPROP_ALIGN,      align);
   SetObjInt(name, OBJPROP_READONLY,   !enabled);
   SetObjInt(name, OBJPROP_BACK,       false);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_SELECTED,   false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     40);

   ObjectSetString(0, name, OBJPROP_FONT, PANEL_FONT);
   SetObjText(name, text);

   return true;
}

//+------------------------------------------------------------------+
//| PANEL - CONSTRUCCIÓN COMPLETA                                    |
//+------------------------------------------------------------------+
void BuildPanel()
{
   // Modo silencioso (tester no-visual): no se construye el panel; todas las
   // rutas de UI quedan inactivas porque comprueban g_panel_built.
   if(IsSilentTesterMode()) return;

   g_suppress_object_events++;

   int top_y = PanelTopY();
   int content_w = PanelContentWidth();
   int btn_w = PanelButtonWidth();
   int third_w = PanelThirdWidth();

   PanelRect("BG", PanelLeftX(), top_y, S(g_panel_width), S(PANEL_HEIGHT),
             ColorBackground(), ColorBorder(), 5);

   PanelRect("HDR", PanelLeftX(), top_y, S(g_panel_width), S(PanelHeaderHeight()),
             ColorHeaderBar(), ColorBorder(), 6);

   PanelIconButton("BTN_GEAR", PanelAbsX(GearOffsetX()), PanelHeaderAbsY(GearOffsetY()),
                   S(PANEL_GEAR_SIZE), S(PANEL_GEAR_SIZE), ICON_CHAR_GEAR,
                   ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorTextWeak(), F(11),
                   "CFG");

   PanelIconButton("BTN_LOCK", PanelAbsX(PadlockOffsetX()), PanelHeaderAbsY(PadlockOffsetY()),
                   S(PANEL_PADLOCK_SIZE), S(PANEL_PADLOCK_SIZE), ICON_CHAR_FREE,
                   ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorTextWeak(), F(11),
                   "O");

   PanelButton("BTN_SELL", PanelAbsX(0), PanelAbsY(PANEL_ROW2_Y),
               S(btn_w), S(PANEL_BUTTON1_HEIGHT),
               "VENTA", ColorSellButton(), ColorSellButtonBorder(), ColorTextStrong(), F(9), true);

   PanelButton("BTN_BUY", PanelAbsX(btn_w + PANEL_BUTTON_GAP), PanelAbsY(PANEL_ROW2_Y),
               S(btn_w), S(PANEL_BUTTON1_HEIGHT),
               "COMPRA", ColorBuyButton(), ColorBuyButtonBorder(), ColorTextStrong(), F(9), true);

   PanelRect("SEP1", PanelAbsX(0), PanelAbsY(PANEL_SEP1_Y), S(content_w), 1,
             ColorBorderSoft(), ColorBorderSoft(), 10);

   PanelLabel("SEC1", PanelAbsX(0), PanelAbsY(PANEL_SEC1_Y), "VOLUMEN Y RIESGO",
              ColorTextMuted(), F(8), true, ANCHOR_LEFT_UPPER);

   PanelLabel("LBL_VOL", PanelAbsX(0), PanelAbsY(PANEL_LOTAJE_Y + 6),
              (InpVolumeMode == VOL_FIXED) ? "Lotaje" : "Riesgo %",
              ColorTextWeak(), F(8), false, ANCHOR_LEFT_UPPER);

   PanelEdit("EDIT_VOL", PanelAbsX(PanelEditOffsetX()), PanelAbsY(PANEL_LOTAJE_Y),
             S(PANEL_EDIT_WIDTH), S(PANEL_EDIT_HEIGHT),
             (InpVolumeMode == VOL_FIXED)
             ? DoubleToString(g_volume, VolumeDecimalsFromStep(_Symbol))
             : DoubleToString(EffectiveRiskPercent(), 2),
             true, F(8), ALIGN_RIGHT);

   PanelRect("SEP2", PanelAbsX(0), PanelAbsY(PANEL_SEP2_Y), S(content_w), 1,
             ColorBorderSoft(), ColorBorderSoft(), 10);

   PanelButton("BTN_EXEC", PanelAbsX(0), PanelAbsY(PANEL_ROW3_Y),
               S(PanelFullRowWidth()), S(PANEL_BUTTON1_HEIGHT),
               "CREA O SELECCIONA UNA POSICIÓN", ColorSurfaceAlt(), ColorBorderSoft(),
               ColorTextStrong(), F(9), true);

   PanelButton("BTN_CLOSE50", PanelAbsX(0), PanelAbsY(PANEL_ROW4_Y),
               S(btn_w), S(PANEL_BUTTON2_HEIGHT), "CERRAR 50%",
               ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText(),
               F(8), false);

   PanelButton("BTN_CLOSE100", PanelAbsX(btn_w + PANEL_BUTTON_GAP), PanelAbsY(PANEL_ROW4_Y),
               S(btn_w), S(PANEL_BUTTON2_HEIGHT), "CERRAR 100%",
               ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText(),
               F(8), false);

   PanelButton("BTN_FLAT", PanelAbsX(0), PanelAbsY(PANEL_ROW5_Y),
               S(third_w), S(PANEL_BUTTON3_HEIGHT), "CERRAR TODO",
               ColorDanger(), ColorSellButtonBorder(), ColorTextStrong(), F(8), true);

   PanelButton("BTN_CANCEL", PanelAbsX(third_w + PANEL_BUTTON_GAP), PanelAbsY(PANEL_ROW5_Y),
               S(third_w), S(PANEL_BUTTON3_HEIGHT), "CANCELAR",
               ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText(),
               F(8), false);

   PanelButton("BTN_DELETE", PanelAbsX(2 * (third_w + PANEL_BUTTON_GAP)), PanelAbsY(PANEL_ROW5_Y),
               S(third_w), S(PANEL_BUTTON3_HEIGHT), "BORRAR",
               ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText(),
               F(8), false);

   PanelRect("SEP3", PanelAbsX(0), PanelAbsY(PANEL_SEP3_Y), S(content_w), 1,
             ColorBorderSoft(), ColorBorderSoft(), 10);

   PanelLabel("SEC3", PanelAbsX(0), PanelAbsY(PANEL_MGMT_HDR_Y), "GESTIÓN AUTOMÁTICA",
              ColorTextMuted(), F(8), true, ANCHOR_LEFT_UPPER);

   PanelButton("BTN_PART", PanelAbsX(0), PanelAbsY(PANEL_MGMT_ROW_Y),
               S(third_w), S(PANEL_MGMT_ROW_H), "Parciales",
               ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText(),
               F(8), false);

   PanelButton("BTN_BE", PanelAbsX(third_w + PANEL_BUTTON_GAP), PanelAbsY(PANEL_MGMT_ROW_Y),
               S(third_w), S(PANEL_MGMT_ROW_H), "Break-even",
               ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText(),
               F(8), false);

   PanelButton("BTN_TRAIL", PanelAbsX(2 * (third_w + PANEL_BUTTON_GAP)), PanelAbsY(PANEL_MGMT_ROW_Y),
               S(third_w), S(PANEL_MGMT_ROW_H), "Trailing",
               ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText(),
               F(8), false);

   PanelRect("SEP4", PanelAbsX(0), PanelAbsY(PANEL_SEP4_Y), S(content_w), 1,
             ColorBorderSoft(), ColorBorderSoft(), 10);

   PanelLabel("SEC4", PanelAbsX(0), PanelAbsY(PANEL_TP_HEADER_Y),
              "PARCIALES", ColorTextMuted(), F(8), true, ANCHOR_LEFT_UPPER);

   PanelLabel("SEC4_COL1",
              PanelAbsX(TPEditMultOffsetX() + TPEditWidth() / 2),
              PanelAbsY(PANEL_TP_HEADER_Y),
              "Objetivo", ColorTextMuted(), F(7), false, ANCHOR_UPPER);

   PanelLabel("SEC4_COL2",
              PanelAbsX(TPEditPctOffsetX() + TPEditWidth() / 2),
              PanelAbsY(PANEL_TP_HEADER_Y),
              "Cierre", ColorTextMuted(), F(7), false, ANCHOR_UPPER);

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      string tag  = IntegerToString(s + 1);
      int    rowy = TPRowOffsetY(s);

      PanelIconButton("CHK_TP" + tag,
                      PanelAbsX(TPCheckboxOffsetX()),
                      PanelAbsY(rowy + (PANEL_TP_EDIT_H - PANEL_TP_CHK_SIZE) / 2),
                      S(PANEL_TP_CHK_SIZE), S(PANEL_TP_CHK_SIZE),
                      g_partial_enabled[s] ? ICON_CHAR_CHECK : " ",
                      g_partial_enabled[s] ? ColorAccentDim() : ColorSurfaceAlt(),
                      ColorBorder(),
                      ColorTextStrong(), F(8));

      PanelLabel("LBL_TP" + tag,
                 PanelAbsX(TPLabelOffsetX()),
                 PanelAbsY(rowy + PANEL_TP_EDIT_H / 2),
                 "TP" + tag, ColorTextWeak(), F(8), false, ANCHOR_LEFT);

      PanelEdit("EDIT_TPM" + tag, PanelAbsX(TPEditMultOffsetX()), PanelAbsY(rowy),
                S(TPEditWidth()), S(PANEL_TP_EDIT_H),
                DoubleToString(g_partial_mult[s], 0), g_partial_enabled[s], F(8), ALIGN_RIGHT);

      PanelLabel("UNIT_TPM" + tag,
                 PanelAbsX(TPUnitMultOffsetX()),
                 PanelAbsY(rowy + PANEL_TP_EDIT_H / 2),
                 "%", ColorTextMuted(), F(8), false, ANCHOR_LEFT);

      PanelEdit("EDIT_TPP" + tag, PanelAbsX(TPEditPctOffsetX()), PanelAbsY(rowy),
                S(TPEditWidth()), S(PANEL_TP_EDIT_H),
                DoubleToString(g_partial_pct[s], 0), g_partial_enabled[s], F(8), ALIGN_RIGHT);

      PanelLabel("UNIT_TPP" + tag,
                 PanelAbsX(TPUnitPctOffsetX()),
                 PanelAbsY(rowy + PANEL_TP_EDIT_H / 2),
                 "%", ColorTextMuted(), F(8), false, ANCHOR_LEFT);
   }

   PanelRect("SEP5", PanelAbsX(0), PanelAbsY(PANEL_SEP5_Y), S(content_w), 1,
             ColorBorderSoft(), ColorBorderSoft(), 10);

   PanelRect("STATUS_BG", PanelAbsX(0), PanelAbsY(PANEL_STATUS_BG_Y),
             S(content_w), S(PANEL_STATUS_BG_H), ColorSurfaceAlt(), ColorBorderSoft(), 11);

   for(int line = 0; line < 3; line++)
      PanelLabel("LBL_ST" + IntegerToString(line),
                 PanelAbsX(PANEL_STATUS_PAD_X), PanelAbsY(PANEL_STATUS_Y + line * PANEL_STATUS_LINE_H),
                 "", ColorTextWeak(), F(7), false, ANCHOR_LEFT_UPPER);

   CachePanelLayout(InpObjectPrefix + "#PANEL#", "", g_panel_x, g_panel_y,
                    g_panel_obj_names, g_panel_obj_rel_x, g_panel_obj_rel_y, g_panel_obj_count);

   g_panel_built = true;
   g_panel_dirty = true;

   g_suppress_object_events--;

   InvalidateControlBounds();

   RaisePanelCanvasToFront();
   UpdatePanelInfo();
   RequestRedraw();
}

void DestroyPanel()
{
   g_flat_arm_until_ms   = 0;
   g_cancel_arm_until_ms = 0;

   g_suppress_object_events++;
   ObjectsDeleteAll(0, InpObjectPrefix + "#PANEL#");
   g_suppress_object_events--;

   ArrayResize(g_panel_obj_names, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_panel_obj_rel_x, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_panel_obj_rel_y, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   g_panel_obj_count = 0;

   g_panel_built = false;

   ClearObjectCache();
   InvalidateControlBounds();
}

void MovePanelTo(int new_x, int new_y)
{
   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   int min_x = S(PANEL_MARGIN);
   int max_x = (int)MathMax(min_x, chart_w - S(g_panel_width));
   int min_y = S(PanelHeaderHeight());
   int max_y = (int)MathMax(min_y, chart_h - S(PANEL_HEIGHT) + S(PanelHeaderHeight()));

   int clamped_x = (int)MathMax(min_x, MathMin(max_x, new_x));
   int clamped_y = (int)MathMax(min_y, MathMin(max_y, new_y));

   if(g_panel_x == clamped_x && g_panel_y == clamped_y)
      return;

   g_panel_x = clamped_x;
   g_panel_y = clamped_y;

   static ulong last_layout_write = 0;
   ulong now = NowMs();

   if(now - last_layout_write >= (ulong)DRAG_REDRAW_THROTTLE_MS)
   {
      last_layout_write     = now;
      g_panel_layout_pending = false;

      ApplyPanelLayout(g_panel_obj_names, g_panel_obj_rel_x, g_panel_obj_rel_y,
                       g_panel_obj_count, g_panel_x, g_panel_y);
      InvalidateControlBounds();

      RequestDragRedraw();
   }
   else
   {
      g_panel_layout_pending = true;
   }
}

void FlushPanelLayoutIfPending()
{
   if(!g_panel_layout_pending) return;
   g_panel_layout_pending = false;

   ApplyPanelLayout(g_panel_obj_names, g_panel_obj_rel_x, g_panel_obj_rel_y,
                    g_panel_obj_count, g_panel_x, g_panel_y);
   InvalidateControlBounds();
   ChartRedraw(0);
}

void MarkPanelDirty()
{
   g_panel_dirty = true;
}

void SetPanelStatus(string text, bool problem)
{
   if(g_panel_status_text == text && g_panel_status_problem == problem) return;

   g_panel_status_text    = text;
   g_panel_status_problem = problem;
   g_panel_status_set_ms  = (text != "") ? NowMs() : 0;

   if(text != "")
      PrintFormat("%s: %s%s", APP_NAME, problem ? "AVISO — " : "", text);

   MarkPanelDirty();
}

void ClearPanelStatus()
{
   if(g_panel_status_text == "") return;

   g_panel_status_text = "";
   g_panel_status_problem = false;
   g_panel_status_set_ms = 0;
   MarkPanelDirty();
}

string CompactPanelText(string text, int max_chars = 68)
{
   if(max_chars < 4 || StringLen(text) <= max_chars) return text;
   return StringSubstr(text, 0, max_chars - 3) + "...";
}

//+------------------------------------------------------------------+
//| PANEL - REFRESCO DE CONTROLES                                    |
//+------------------------------------------------------------------+
void RefreshPartialCheckboxes()
{
   if(!g_panel_built) return;

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      string tag = IntegerToString(s + 1);
      string chk = ObjectNameForPanel("CHK_TP" + tag);
      string em  = ObjectNameForPanel("EDIT_TPM" + tag);
      string ep  = ObjectNameForPanel("EDIT_TPP" + tag);

      bool on = g_partial_enabled[s];

      SetObjText(chk, on ? ICON_CHAR_CHECK : " ");
      SetObjInt(chk, OBJPROP_BGCOLOR, on ? ColorAccentDim() : ColorSurfaceAlt());

      SetObjInt(em, OBJPROP_READONLY, !on);
      SetObjInt(ep, OBJPROP_READONLY, !on);
      SetObjInt(em, OBJPROP_BGCOLOR,  ColorEditBackground(on));
      SetObjInt(ep, OBJPROP_BGCOLOR,  ColorEditBackground(on));
      SetObjInt(em, OBJPROP_COLOR,    ColorEditText(on));
      SetObjInt(ep, OBJPROP_COLOR,    ColorEditText(on));
      SetObjInt(em, OBJPROP_BORDER_COLOR, ColorEditBorder(on));
      SetObjInt(ep, OBJPROP_BORDER_COLOR, ColorEditBorder(on));

      if(NowMs() - g_last_edit_ms > (ulong)EDIT_OVERWRITE_GUARD_MS)
      {
         SetObjText(em, DoubleToString(g_partial_mult[s], 0));
         SetObjText(ep, DoubleToString(g_partial_pct[s],  0));
      }
   }
}

void RefreshManagementToggles()
{
   if(!g_panel_built) return;

   string names[3]  = { "BTN_PART", "BTN_BE", "BTN_TRAIL" };
   bool   states[3] = { g_enable_partials, g_enable_breakeven, g_enable_trailing };

   for(int i = 0; i < 3; i++)
   {
      string n = ObjectNameForPanel(names[i]);

      SetObjInt(n, OBJPROP_BGCOLOR, states[i] ? ColorAccentDim() : ColorButtonNeutralBg());
      SetObjInt(n, OBJPROP_BORDER_COLOR, states[i] ? ColorAccent() : ColorButtonNeutralBorder());
      SetObjInt(n, OBJPROP_COLOR, states[i] ? ColorTextStrong() : ColorButtonNeutralText());
   }
}

void RefreshLockButton()
{
   if(!g_panel_built) return;

   int  idx    = GetTargetPositionIndex();
   bool locked = (idx >= 0) ? g_positions[idx].is_locked : false;

   string n = ObjectNameForPanel("BTN_LOCK");

   string glyph;
   if(idx < 0)      glyph = g_icon_font_usable ? ICON_CHAR_NONE  : "-";
   else if(locked)  glyph = g_icon_font_usable ? ICON_CHAR_LOCKED : "X";
   else             glyph = g_icon_font_usable ? ICON_CHAR_FREE   : "O";

   SetObjText(n, glyph);
   SetObjInt(n, OBJPROP_COLOR, (idx < 0) ? ColorTextDisabled()
                               : (locked ? ColorWarning() : ColorTextWeak()));
   ObjectSetString(0, n, OBJPROP_TOOLTIP,
                   locked ? "Bloqueada: sigue Ask en compra o Bid en venta."
                          : "Desbloqueada: puede editar los niveles manualmente.");
}

void UpdatePanelInfo()
{
   if(!g_panel_built) return;

   const ulong STATUS_DISPLAY_MS = 8000;
   if(g_panel_status_text != "" && g_panel_status_set_ms > 0)
   {
      if(NowMs() - g_panel_status_set_ms > STATUS_DISPLAY_MS)
         ClearPanelStatus();
   }

   RefreshManagementToggles();
   RefreshPartialCheckboxes();
   RefreshLockButton();

   string lbl_vol = ObjectNameForPanel("LBL_VOL");
   SetObjText(lbl_vol, (InpVolumeMode == VOL_FIXED) ? "Lotaje" : "Riesgo %");

   if(NowMs() - g_last_edit_ms > (ulong)EDIT_OVERWRITE_GUARD_MS)
   {
      SetObjText(ObjectNameForPanel("EDIT_VOL"),
                 (InpVolumeMode == VOL_FIXED)
                 ? DoubleToString(g_volume, VolumeDecimalsFromStep(_Symbol))
                 : DoubleToString(EffectiveRiskPercent(), 2));
   }

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   string line0 = StringFormat("EQ %s  ·  BAL %s  ·  %s",
                               FormatMoneyFull(equity), FormatMoneyFull(balance),
                               g_is_limit_locked ? "LÍMITE ACTIVO" :
                               (g_exec_allowed ? "operativo" : "sin ejecución"));

   int idx = GetTargetPositionIndex();
   string line1;
   string exec_button = "";
   bool can_execute = false;

   if(idx < 0)
   {
      line1 = "Crea una posición con COMPRA o VENTA para empezar.";
      exec_button = "CREA O SELECCIONA UNA POSICIÓN";
   }
   else
   {
      SVisualPosition pos = g_positions[idx];
      string type_str = (pos.type == PLANNER_POS_BUY) ? "COMPRA" : "VENTA";
      string status_str = ZoneStatusWord(pos);

      line1 = StringFormat("Posición #%d (%s)  ·  %s",
                           ZoneDisplayNumber(idx),
                           type_str,
                           status_str);

      can_execute = IsPositionExecutable(idx) && pos.is_locked &&
                    !HasActiveOrder(idx) && g_exec_allowed && !g_is_limit_locked &&
                    !g_order_retry_active;
      exec_button = can_execute
                    ? StringFormat("EJECUTAR POSICIÓN #%d", ZoneDisplayNumber(idx))
                    : "POSICIÓN NO DISPONIBLE PARA EJECUCIÓN";
   }

   string exec_name = ObjectNameForPanel("BTN_EXEC");
   SetObjText(exec_name, exec_button);
   SetObjInt(exec_name, OBJPROP_BGCOLOR,
             can_execute ? ColorActionButton() : ColorSurfaceAlt());
   SetObjInt(exec_name, OBJPROP_BORDER_COLOR,
             can_execute ? ColorActionButtonBorder() : ColorBorderSoft());
   SetObjInt(exec_name, OBJPROP_COLOR,
             can_execute ? ColorTextStrong() : ColorTextMuted());

   string line2 = (g_panel_status_text != "")
                  ? g_panel_status_text
                  : (g_degraded_mode ? g_degraded_reason : "Listo para planificar una operación.");

   string st0 = ObjectNameForPanel("LBL_ST0");
   string st1 = ObjectNameForPanel("LBL_ST1");
   string st2 = ObjectNameForPanel("LBL_ST2");

   SetObjText(st0, CompactPanelText(line0));
   SetObjText(st1, CompactPanelText(line1));
   SetObjText(st2, CompactPanelText(line2));
   ObjectSetString(0, st0, OBJPROP_TOOLTIP, line0);
   ObjectSetString(0, st1, OBJPROP_TOOLTIP, line1);
   ObjectSetString(0, st2, OBJPROP_TOOLTIP, line2);

   SetObjInt(st0, OBJPROP_COLOR,
             g_is_limit_locked ? ColorDanger() : ColorTextWeak());
   SetObjInt(st2, OBJPROP_COLOR,
             g_panel_status_problem ? ColorWarning() : ColorTextMuted());
   SetObjInt(ObjectNameForPanel("STATUS_BG"), OBJPROP_BGCOLOR,
             g_panel_status_problem ? C'45,31,31' : ColorSurfaceAlt());

   g_panel_dirty = false;
}

//+------------------------------------------------------------------+
//| PANEL DE CONFIGURACIÓN - METADATOS Y ACCESO A CAMPOS             |
//+------------------------------------------------------------------+
void InitSettingsMetadata()
{
   g_settings_labels[0]  = "Riesgo %";              g_settings_hints[0]  = "0.01 - 100";
   g_settings_labels[1]  = "Lotaje fijo";           g_settings_hints[1]  = "lotes";
   g_settings_labels[2]  = "TP por defecto";        g_settings_hints[2]  = "ticks";
   g_settings_labels[3]  = "SL por defecto";        g_settings_hints[3]  = "ticks";
   g_settings_labels[4]  = "Ancho de posición";     g_settings_hints[4]  = "barras";
   g_settings_labels[5]  = "Transparencia";         g_settings_hints[5]  = "0 - 100";
   g_settings_labels[6]  = "Desviación máx.";       g_settings_hints[6]  = "puntos";
   g_settings_labels[7]  = "Reintentos de orden";   g_settings_hints[7]  = "1 - 20";
   g_settings_labels[8]  = "Backoff base";          g_settings_hints[8]  = "ms";
   g_settings_labels[9]  = "BE offset";             g_settings_hints[9]  = "ticks";
   g_settings_labels[10] = "BE inicio";             g_settings_hints[10] = "R";
   g_settings_labels[11] = "Trailing inicio";       g_settings_hints[11] = "R";
   g_settings_labels[12] = "Trailing distancia";    g_settings_hints[12] = "ticks";
   g_settings_labels[13] = "Trailing paso";         g_settings_hints[13] = "ticks";
   g_settings_labels[14] = "ATR multiplicador";     g_settings_hints[14] = "x";
   g_settings_labels[15] = "Zoom del panel";        g_settings_hints[15] = "0.7 - 2.0";
   g_settings_labels[16] = "Tamaño de fuente";      g_settings_hints[16] = "6 - 12";
   g_settings_labels[17] = "Ancho de línea";        g_settings_hints[17] = "1 - 5";
   g_settings_labels[18] = "Límite pérdida día";    g_settings_hints[18] = "USD";
   g_settings_labels[19] = "Límite pérdida sem.";   g_settings_hints[19] = "USD";
   g_settings_labels[20] = "Tolerancia entrada";    g_settings_hints[20] = "ticks";
   g_settings_labels[21] = "Intervalo gestión";     g_settings_hints[21] = "seg";
}

double SettingsFieldValue(int field)
{
   switch(field)
   {
      case 0:  return EffectiveRiskPercent();
      case 1:  return g_volume;
      case 2:  return (double)g_tp_ticks;
      case 3:  return (double)g_sl_ticks;
      case 4:  return (double)g_zone_width_bars;
      case 5:  return (double)g_transparency;
      case 6:  return (double)g_max_deviation;
      case 7:  return (double)g_max_retries;
      case 8:  return (double)g_backoff_base;
      case 9:  return (double)g_be_offset_ticks;
      case 10: return g_be_start_r;
      case 11: return g_trailing_start_r;
      case 12: return (double)g_trailing_ticks;
      case 13: return (double)g_trailing_step_ticks;
      case 14: return g_trailing_atr_multiplier;
      case 15: return g_panel_zoom;
      case 16: return (double)g_font_size_stats;
      case 17: return (double)g_line_width;
      case 18: return g_daily_loss_limit;
      case 19: return g_weekly_loss_limit;
      case 20: return g_entry_tolerance_ticks;
      case 21: return (double)g_management_interval;
   }
   return 0.0;
}

int SettingsFieldDecimals(int field)
{
   switch(field)
   {
      case 0:  return 2;
      case 1:  return VolumeDecimalsFromStep(_Symbol);
      case 10: return 2;
      case 11: return 2;
      case 14: return 2;
      case 15: return 2;
      case 18: return 2;
      case 19: return 2;
      case 20: return 1;
   }
   return 0;
}

bool ApplySettingsField(int field, double value, string &error)
{
   error = "";

   bool needs_visual_recalc = false;

   switch(field)
   {
      case 0:
         if(value < 0.01 || value > 100.0) { error = "Riesgo % fuera de rango (0.01 - 100)."; return false; }
         g_effective_risk_percent = value;
         InvalidateAllZoneVolumes();
         needs_visual_recalc = true;
         break;

      case 1:
      {
         bool below;
         double v = NormalizeVolume(_Symbol, value, below);
         if(below || v <= 0.0) { error = "Lotaje por debajo del mínimo del símbolo."; return false; }
         g_volume = v;
         InvalidateAllZoneVolumes();
         needs_visual_recalc = true;
         break;
      }

      case 2:
         if(value < 1.0) { error = "El TP debe ser de al menos 1 tick."; return false; }
         g_tp_ticks = (int)MathRound(value);
         needs_visual_recalc = true;
         break;

      case 3:
         if(value < 1.0) { error = "El SL debe ser de al menos 1 tick."; return false; }
         g_sl_ticks = (int)MathRound(value);
         needs_visual_recalc = true;
         break;

      case 4:
         if(value < 1.0 || value > 500.0) { error = "Ancho de posición fuera de rango (1 - 500)."; return false; }
         g_zone_width_bars = (int)MathRound(value);
         needs_visual_recalc = true;
         break;

      case 5:
         if(value < 0.0 || value > 100.0) { error = "Transparencia fuera de rango (0 - 100)."; return false; }
         g_transparency = (int)MathRound(value);
         needs_visual_recalc = true;
         break;

      case 6:
         if(value < 0.0 || value > 1000.0) { error = "Desviación fuera de rango (0 - 1000)."; return false; }
         g_max_deviation = (int)MathRound(value);
         ConfigureTradeObject();
         break;

      case 7:
         if(value < 1.0 || value > 20.0) { error = "Reintentos fuera de rango (1 - 20)."; return false; }
         g_max_retries = (int)MathRound(value);
         break;

      case 8:
         if(value < 50.0 || value > 5000.0) { error = "Backoff fuera de rango (50 - 5000 ms)."; return false; }
         g_backoff_base = (int)MathRound(value);
         break;

      case 9:
         if(value < 0.0 || value > 10000.0) { error = "BE offset fuera de rango."; return false; }
         g_be_offset_ticks = (int)MathRound(value);
         break;

      case 10:
         if(value < 0.0 || value > 100.0) { error = "BE inicio fuera de rango (0 - 100 R)."; return false; }
         g_be_start_r = value;
         break;

      case 11:
         if(value < 0.0 || value > 100.0) { error = "Trailing inicio fuera de rango (0 - 100 R)."; return false; }
         g_trailing_start_r = value;
         break;

      case 12:
         if(value < 1.0) { error = "La distancia de trailing debe ser >= 1 tick."; return false; }
         g_trailing_ticks = (int)MathRound(value);
         break;

      case 13:
         if(value < 1.0) { error = "El paso de trailing debe ser >= 1 tick."; return false; }
         g_trailing_step_ticks = (int)MathRound(value);
         break;

      case 14:
         if(value < 0.1 || value > 20.0) { error = "Multiplicador ATR fuera de rango (0.1 - 20)."; return false; }
         g_trailing_atr_multiplier = value;
         break;

      case 15:
      {
         if(value < 0.7 || value > 2.0) { error = "Zoom fuera de rango (0.7 - 2.0)."; return false; }
         g_panel_zoom = value;
         g_pending_panel_rebuild = true;
         break;
      }

      case 16:
         if(value < 6.0 || value > 12.0) { error = "Tamaño de fuente fuera de rango (6 - 12)."; return false; }
         g_font_size_stats = (int)MathRound(value);
         needs_visual_recalc = true;
         break;

      case 17:
         if(value < 1.0 || value > 5.0) { error = "Ancho de línea fuera de rango (1 - 5)."; return false; }
         g_line_width = (int)MathRound(value);
         needs_visual_recalc = true;
         break;

      case 18:
         if(value < 0.0) { error = "El límite diario no puede ser negativo."; return false; }
         g_daily_loss_limit = value;
         break;

      case 19:
         if(value < 0.0) { error = "El límite semanal no puede ser negativo."; return false; }
         g_weekly_loss_limit = value;
         break;

      case 20:
         if(value < 0.0 || value > 100.0) { error = "Tolerancia de entrada fuera de rango (0 - 100)."; return false; }
         g_entry_tolerance_ticks = value;
         break;

      case 21:
         if(value < 1.0 || value > 60.0) { error = "Intervalo de gestión fuera de rango (1 - 60 seg)."; return false; }
         g_management_interval = (int)MathRound(value);
         break;

      default:
         error = "Campo desconocido.";
         return false;
   }

   ClampLiveSettings();
   RecomputeManagementFlags();
   if(needs_visual_recalc) RecalculateAllPositions();
   SaveLiveConfig();
   MarkPanelDirty();

   return true;
}

//+------------------------------------------------------------------+
//| PANEL DE CONFIGURACIÓN - CONSTRUCCIÓN                            |
//+------------------------------------------------------------------+
string SettingsObjName(string suffix)
{
   return InpObjectPrefix + "#CFG#" + suffix;
}

bool SettingsRect(string suffix, int x, int y, int w, int h, color bg, color border, int z)
{
   string name = SettingsObjName(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_RECTANGLE_LABEL, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,   x);
   SetObjInt(name, OBJPROP_YDISTANCE,   y);
   SetObjInt(name, OBJPROP_XSIZE,       w);
   SetObjInt(name, OBJPROP_YSIZE,       h);
   SetObjInt(name, OBJPROP_BGCOLOR,     bg);
   SetObjInt(name, OBJPROP_COLOR,       border);
   SetObjInt(name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   SetObjInt(name, OBJPROP_BACK,        false);
   SetObjInt(name, OBJPROP_SELECTABLE,  false);
   SetObjInt(name, OBJPROP_HIDDEN,      true);
   SetObjInt(name, OBJPROP_ZORDER,      z);

   return true;
}

bool SettingsLabel(string suffix, int x, int y, string text, color c, int font_pt, bool bold,
                   ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   string name = SettingsObjName(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_LABEL, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,  x);
   SetObjInt(name, OBJPROP_YDISTANCE,  y);
   SetObjInt(name, OBJPROP_ANCHOR,     anchor);
   SetObjInt(name, OBJPROP_COLOR,      c);
   SetObjInt(name, OBJPROP_FONTSIZE,   font_pt);
   SetObjInt(name, OBJPROP_BACK,       false);
   SetObjInt(name, OBJPROP_SELECTABLE, false);
   SetObjInt(name, OBJPROP_HIDDEN,     true);
   SetObjInt(name, OBJPROP_ZORDER,     20);

   ObjectSetString(0, name, OBJPROP_FONT, bold ? PANEL_FONT_BOLD : PANEL_FONT);
   SetObjText(name, text);

   return true;
}

bool SettingsEdit(string suffix, int x, int y, int w, int h, string text)
{
   string name = SettingsObjName(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_EDIT, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,    x);
   SetObjInt(name, OBJPROP_YDISTANCE,    y);
   SetObjInt(name, OBJPROP_XSIZE,        w);
   SetObjInt(name, OBJPROP_YSIZE,        h);
   SetObjInt(name, OBJPROP_BGCOLOR,      ColorSurface());
   SetObjInt(name, OBJPROP_BORDER_COLOR, ColorBorder());
   SetObjInt(name, OBJPROP_COLOR,        ColorTextStrong());
   SetObjInt(name, OBJPROP_FONTSIZE,     F(8));
   SetObjInt(name, OBJPROP_ALIGN,        ALIGN_RIGHT);
   SetObjInt(name, OBJPROP_READONLY,     false);
   SetObjInt(name, OBJPROP_BACK,         false);
   SetObjInt(name, OBJPROP_SELECTABLE,   false);
   SetObjInt(name, OBJPROP_SELECTED,     false);
   SetObjInt(name, OBJPROP_HIDDEN,       true);
   SetObjInt(name, OBJPROP_ZORDER,       40);

   ObjectSetString(0, name, OBJPROP_FONT, PANEL_FONT);
   SetObjText(name, text);

   return true;
}

bool SettingsButton(string suffix, int x, int y, int w, int h, string text,
                    color bg, color border, color text_color)
{
   string name = SettingsObjName(suffix);

   if(ObjectFind(0, name) < 0)
      if(!ObjectCreateChecked(name, OBJ_BUTTON, 0, 0, 0, 0.0, false))
         return false;

   SetObjInt(name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   SetObjInt(name, OBJPROP_XDISTANCE,    x);
   SetObjInt(name, OBJPROP_YDISTANCE,    y);
   SetObjInt(name, OBJPROP_XSIZE,        w);
   SetObjInt(name, OBJPROP_YSIZE,        h);
   SetObjInt(name, OBJPROP_BGCOLOR,      bg);
   SetObjInt(name, OBJPROP_BORDER_COLOR, border);
   SetObjInt(name, OBJPROP_COLOR,        text_color);
   SetObjInt(name, OBJPROP_FONTSIZE,     F(8));
   SetObjInt(name, OBJPROP_STATE,        false);
   SetObjInt(name, OBJPROP_BACK,         false);
   SetObjInt(name, OBJPROP_SELECTABLE,   false);
   SetObjInt(name, OBJPROP_SELECTED,     false);
   SetObjInt(name, OBJPROP_HIDDEN,       true);
   SetObjInt(name, OBJPROP_ZORDER,       40);

   ObjectSetString(0, name, OBJPROP_FONT, PANEL_FONT);
   SetObjText(name, text);

   return true;
}

void BuildSettingsPanel()
{
   g_suppress_object_events++;

   int rows_h = SETTINGS_FIELDS * SETTINGS_ROW_STEP;
   int total_h = SETTINGS_HEADER_H + rows_h + SETTINGS_FOOTER_H + 2 * SETTINGS_MARGIN;

   SettingsRect("BG", g_settings_x, g_settings_y, S(SETTINGS_WIDTH), S(total_h),
                ColorBackground(), ColorAccentDim(), 5);

   SettingsRect("HDR", g_settings_x, g_settings_y, S(SETTINGS_WIDTH), S(SETTINGS_HEADER_H),
                ColorHeaderBar(), ColorAccentDim(), 6);

   SettingsLabel("TITLE", g_settings_x + S(SETTINGS_MARGIN), g_settings_y + S(12),
                 "Configuración", ColorTextStrong(), F(10), true);

   SettingsButton("BTN_X", g_settings_x + S(SETTINGS_WIDTH - SETTINGS_MARGIN - 24),
                  g_settings_y + S(8), S(24), S(24), ICON_CHAR_CLOSED,
                  ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorTextWeak());

   for(int i = 0; i < SETTINGS_FIELDS; i++)
   {
      string tag = IntegerToString(i);
      int    ry  = g_settings_y + S(SETTINGS_HEADER_H + SETTINGS_MARGIN + i * SETTINGS_ROW_STEP);

      SettingsLabel("LBL" + tag, g_settings_x + S(SETTINGS_MARGIN), ry + S(5),
                    g_settings_labels[i], ColorTextWeak(), F(8), false);

      SettingsEdit("EDIT" + tag,
                   g_settings_x + S(SETTINGS_WIDTH - SETTINGS_MARGIN - SETTINGS_HINT_W
                                     - SETTINGS_HINT_GAP - SETTINGS_EDIT_W),
                   ry, S(SETTINGS_EDIT_W), S(SETTINGS_ROW_H),
                   DoubleToString(SettingsFieldValue(i), SettingsFieldDecimals(i)));

      SettingsLabel("UNIT" + tag,
                    g_settings_x + S(SETTINGS_WIDTH - SETTINGS_MARGIN), ry + S(5),
                    g_settings_hints[i], ColorTextMuted(), F(7), false, ANCHOR_RIGHT_UPPER);
   }

   int footer_y = g_settings_y + S(SETTINGS_HEADER_H + SETTINGS_MARGIN + rows_h + 4);

   SettingsLabel("ERR", g_settings_x + S(SETTINGS_MARGIN), footer_y + S(6),
                 "", ColorWarning(), F(7), false);

   SettingsButton("BTN_RESET", g_settings_x + S(SETTINGS_MARGIN), footer_y + S(SETTINGS_ROW_H - 2),
                  S(SETTINGS_WIDTH - 2 * SETTINGS_MARGIN), S(SETTINGS_ROW_H),
                  "Restaurar valores de los inputs",
                  ColorButtonNeutralBg(), ColorButtonNeutralBorder(), ColorButtonNeutralText());

   CachePanelLayout(InpObjectPrefix + "#CFG#", "", g_settings_x, g_settings_y,
                    g_settings_obj_names, g_settings_obj_rel_x, g_settings_obj_rel_y,
                    g_settings_obj_count);

   g_settings_panel_built = true;
   g_settings_panel_open  = true;

   g_suppress_object_events--;

   RaisePanelCanvasToFront();
   RequestRedraw();
}

void DestroySettingsPanel()
{
   g_suppress_object_events++;
   ObjectsDeleteAll(0, InpObjectPrefix + "#CFG#");
   g_suppress_object_events--;

   ArrayResize(g_settings_obj_names, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_settings_obj_rel_x, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   ArrayResize(g_settings_obj_rel_y, 0, INITIAL_PANEL_OBJECTS_CAPACITY);
   g_settings_obj_count = 0;

   g_settings_panel_built = false;
   g_settings_panel_open  = false;

   InvalidateControlBounds();

   RequestRedraw();
}

void ToggleSettingsPanel()
{
   if(g_settings_panel_open) DestroySettingsPanel();
   else                      BuildSettingsPanel();
}

void SetSettingsError(string text)
{
   g_settings_edit_error = text;

   if(g_settings_panel_built)
      SetObjText(SettingsObjName("ERR"), text);

   if(text != "") PrintFormat("%s: configuración — %s", APP_NAME, text);
}

void MoveSettingsTo(int new_x, int new_y)
{
   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   int rows_h           = SETTINGS_FIELDS * SETTINGS_ROW_STEP;
   int settings_total_h = SETTINGS_HEADER_H + rows_h + SETTINGS_FOOTER_H + 2 * SETTINGS_MARGIN;

   int clamped_x = (int)MathMax(0, MathMin(chart_w - S(SETTINGS_WIDTH), new_x));
   int clamped_y = (int)MathMax(0, MathMin(chart_h - S(settings_total_h), new_y));

   if(g_settings_x == clamped_x && g_settings_y == clamped_y)
      return;

   g_settings_x = clamped_x;
   g_settings_y = clamped_y;

   static ulong last_layout_write = 0;
   ulong now = NowMs();

   if(now - last_layout_write >= (ulong)DRAG_REDRAW_THROTTLE_MS)
   {
      last_layout_write         = now;
      g_settings_layout_pending = false;

      ApplyPanelLayout(g_settings_obj_names, g_settings_obj_rel_x, g_settings_obj_rel_y,
                       g_settings_obj_count, g_settings_x, g_settings_y);
      InvalidateControlBounds();

      RequestDragRedraw();
   }
   else
   {
      g_settings_layout_pending = true;
   }
}

void FlushSettingsLayoutIfPending()
{
   if(!g_settings_layout_pending) return;
   g_settings_layout_pending = false;

   ApplyPanelLayout(g_settings_obj_names, g_settings_obj_rel_x, g_settings_obj_rel_y,
                    g_settings_obj_count, g_settings_x, g_settings_y);
   InvalidateControlBounds();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| INTERACCIÓN CON POSICIONES - DETECCIÓN DE OBJETIVO               |
//+------------------------------------------------------------------+
bool ZoneHitTest(int px, int py, long &out_id, ENUM_DRAG_MODE &out_mode, int &out_stage)
{
   out_id    = -1;
   out_mode  = DRAG_NONE;
   out_stage = -1;

   datetime t = 0;
   double   price = 0.0;
   if(!ChartPointToTimePrice(px, py, t, price)) return false;

   double ppp = PricePerPixel();
   if(ppp <= 0.0) return false;

   double line_tol  = ppp * MOUSE_CLICK_THRESHOLD;
   double entry_tol = ppp * MOUSE_CLICK_THRESHOLD_ENTRY;

   int best_idx = -1;
   ENUM_DRAG_MODE best_mode = DRAG_NONE;
   int best_stage = -1;
   double best_dist = 0.0;

   for(int i = ArraySize(g_positions) - 1; i >= 0; i--)
   {
      SVisualPosition pos = g_positions[i];
      if(pos.id < 0) continue;
      if(pos.is_closed) continue;

      datetime t1 = pos.time_start;
      datetime t2 = pos.time_end;
      if(t2 <= t1) t2 = BarTimeAtOffset(t1, (int)MathMax(1, g_zone_width_bars));

      int x_left = 0, y_left = 0, x_right = 0, y_right = 0;
      if(ChartTimePriceToXY(0, 0, t1, pos.entry_price, x_left, y_left) &&
         ChartTimePriceToXY(0, 0, t2, pos.entry_price, x_right, y_right))
      {
         double upper = MathMax(pos.tp_price, pos.sl_price);
         double lower = MathMin(pos.tp_price, pos.sl_price);
         bool within_height = (price >= lower - line_tol && price <= upper + line_tol);

         int y_tp_handle = 0, y_sl_handle = 0, dummy_hx = 0;
         ChartTimePriceToXY(0, 0, t1, pos.tp_price, dummy_hx, y_tp_handle);
         ChartTimePriceToXY(0, 0, t1, pos.sl_price, dummy_hx, y_sl_handle);

         bool zone_handles_visible = (pos.id == g_selected_id || pos.id == g_hover_id) &&
                                     !pos.is_degenerate;

         if(MathAbs(px - x_left) <= MOUSE_CLICK_THRESHOLD)
         {
            if(zone_handles_visible && MathAbs(py - y_tp_handle) <= MOUSE_CLICK_THRESHOLD)
            {
               out_id = pos.id; out_mode = DRAG_TP_LINE; out_stage = -1;
               return true;
            }

            if(zone_handles_visible && MathAbs(py - y_sl_handle) <= MOUSE_CLICK_THRESHOLD)
            {
               out_id = pos.id; out_mode = DRAG_SL_LINE; out_stage = -1;
               return true;
            }

            if(zone_handles_visible && !pos.is_locked && MathAbs(py - y_left) <= MOUSE_CLICK_THRESHOLD)
            {
               out_id = pos.id; out_mode = DRAG_ENTRY_LEFT; out_stage = -1;
               return true;
            }
         }

         if(zone_handles_visible &&
            MathAbs(px - x_right) <= MOUSE_CLICK_THRESHOLD &&
            MathAbs(py - y_right) <= MOUSE_CLICK_THRESHOLD)
         {
            out_id = pos.id; out_mode = DRAG_ENTRY_RIGHT; out_stage = -1;
            return true;
         }

         if(within_height && !pos.is_locked && MathAbs(px - x_left) <= MOUSE_CLICK_THRESHOLD)
         {
            out_id = pos.id; out_mode = DRAG_LEFT_BORDER; out_stage = -1;
            return true;
         }

         if(within_height && MathAbs(px - x_right) <= MOUSE_CLICK_THRESHOLD)
         {
            out_id = pos.id; out_mode = DRAG_RIGHT_BORDER; out_stage = -1;
            return true;
         }

         if(px >= x_right - MOUSE_CLICK_THRESHOLD && px <= x_right + LABEL_HIT_WIDTH_PX)
         {
            int y_tp = 0, y_sl = 0, dummy_x = 0;
            ChartTimePriceToXY(0, 0, t2, pos.tp_price, dummy_x, y_tp);
            ChartTimePriceToXY(0, 0, t2, pos.sl_price, dummy_x, y_sl);

            if(MathAbs(py - y_right) <= LABEL_HIT_HEIGHT_PX)
            {
               out_id = pos.id; out_mode = DRAG_ENTRY_LINE; out_stage = -1;
               return true;
            }

            if(MathAbs(py - y_tp) <= LABEL_HIT_HEIGHT_PX)
            {
               out_id = pos.id; out_mode = DRAG_TP_LINE; out_stage = -1;
               return true;
            }

            if(MathAbs(py - y_sl) <= LABEL_HIT_HEIGHT_PX)
            {
               out_id = pos.id; out_mode = DRAG_SL_LINE; out_stage = -1;
               return true;
            }
         }
      }

      if(t < t1 || t > t2) continue;

      double d_entry = MathAbs(price - pos.entry_price);
      double d_tp    = MathAbs(price - pos.tp_price);
      double d_sl    = MathAbs(price - pos.sl_price);

      if(d_entry <= entry_tol &&
         (best_idx < 0 || d_entry < best_dist))
      {
         best_idx = i; best_mode = DRAG_ENTRY_LINE; best_stage = -1; best_dist = d_entry;
      }

      if(d_tp <= line_tol && (best_idx < 0 || d_tp < best_dist))
      {
         best_idx = i; best_mode = DRAG_TP_LINE; best_stage = -1; best_dist = d_tp;
      }

      if(d_sl <= line_tol && (best_idx < 0 || d_sl < best_dist))
      {
         best_idx = i; best_mode = DRAG_SL_LINE; best_stage = -1; best_dist = d_sl;
      }

      for(int s = 0; s < PARTIAL_STAGES; s++)
      {
         if(!PartialStageActive(pos, s)) continue;

         double stage_price = PartialStagePrice(pos, s);
         if(stage_price <= 0.0) continue;

         double d_stage = MathAbs(price - stage_price);
         if(d_stage <= line_tol && (best_idx < 0 || d_stage < best_dist))
         {
            best_idx = i; best_mode = DRAG_PARTIAL_LINE; best_stage = s; best_dist = d_stage;
         }
      }

      if(best_idx < 0)
      {
         bool inside_tp = (pos.type == PLANNER_POS_BUY)
                          ? (price > pos.entry_price && price < pos.tp_price)
                          : (price < pos.entry_price && price > pos.tp_price);
         bool inside_sl = (pos.type == PLANNER_POS_BUY)
                          ? (price < pos.entry_price && price > pos.sl_price)
                          : (price > pos.entry_price && price < pos.sl_price);

         if(inside_tp || inside_sl)
         {
            best_idx = i; best_mode = DRAG_ENTIRE_ZONE; best_stage = -1; best_dist = 0.0;
         }
      }
   }

   if(best_idx < 0) return false;

   out_id    = g_positions[best_idx].id;
   out_mode  = best_mode;
   out_stage = best_stage;

   return true;
}

//+------------------------------------------------------------------+
//| INTERACCIÓN CON POSICIONES - ARRASTRE                            |
//+------------------------------------------------------------------+
void BeginZoneDrag(long id, ENUM_DRAG_MODE mode, int stage, datetime t, double price)
{
   int idx = FindPositionById(id);
   if(idx < 0) return;

   SVisualPosition pos = g_positions[idx];

   bool locked_draft = pos.is_locked && !pos.is_executed && !pos.is_closed &&
                       pos.order_ticket == 0;

   bool allowed_while_locked = (locked_draft && (mode == DRAG_RIGHT_BORDER ||
                                                  mode == DRAG_ENTRY_RIGHT)) ||
                               mode == DRAG_TP_LINE || mode == DRAG_SL_LINE;

   if(pos.is_locked && !allowed_while_locked)
   {
      if(!g_drag_warned)
      {
         SetPanelStatus("Bloqueada: el nivel de apertura no se puede mover; TP y SL sí.", true);
         g_drag_warned = true;
      }
      return;
   }

   g_drag_mode      = mode;
   g_drag_id        = id;
   g_drag_stage     = stage;
   g_drag_ref_price = price;
   g_drag_ref_time  = t;
   g_drag_warned    = false;

   g_drag_snap_entry = pos.entry_price;
   g_drag_snap_tp    = pos.tp_price;
   g_drag_snap_sl    = pos.sl_price;
   g_drag_snap_t1    = pos.time_start;
   g_drag_snap_t2    = pos.time_end;

   for(int s = 0; s < PARTIAL_STAGES; s++)
      g_drag_snap_partial_stage[s] = PartialStagePrice(pos, s);

   SelectZone(id);
}

void CancelZoneDrag(bool restore)
{
   if(g_drag_mode == DRAG_NONE) return;

   int idx = FindPositionById(g_drag_id);

   if(restore && idx >= 0)
   {
      g_positions[idx].entry_price = g_drag_snap_entry;
      g_positions[idx].tp_price    = g_drag_snap_tp;
      g_positions[idx].sl_price    = g_drag_snap_sl;
      g_positions[idx].time_start  = g_drag_snap_t1;
      g_positions[idx].time_end    = g_drag_snap_t2;

      InvalidateZoneVolume(idx);
      UpdatePositionObjects(idx);
   }

   g_drag_mode  = DRAG_NONE;
   g_drag_id    = -1;
   g_drag_stage = -1;

   RequestRedraw();
}

void UpdateZoneDrag(int px, int py)
{
   if(g_drag_mode == DRAG_NONE) return;

   int idx = FindPositionById(g_drag_id);
   if(idx < 0) { CancelZoneDrag(false); return; }

   datetime t = 0;
   double   price = 0.0;
   if(!ChartPointToTimePrice(px, py, t, price)) return;

   double delta_price = price - g_drag_ref_price;
   bool   is_long     = (g_positions[idx].type == PLANNER_POS_BUY);

   switch(g_drag_mode)
   {
      case DRAG_ENTRY_LINE:
      {
         double new_entry = NormalizeToTick(price);
         if(new_entry <= 0.0) return;

         bool valid = is_long
                      ? (new_entry < g_positions[idx].tp_price && new_entry > g_positions[idx].sl_price)
                      : (new_entry > g_positions[idx].tp_price && new_entry < g_positions[idx].sl_price);
         if(!valid)
         {
            if(!g_drag_warned)
            {
               SetPanelStatus("La apertura no puede cruzar el TP ni el SL.", true);
               g_drag_warned = true;
            }
            return;
         }

         g_positions[idx].entry_price = new_entry;
         break;
      }

      case DRAG_ENTRY_LEFT:
      case DRAG_ENTRY_RIGHT:
      {
         if(g_drag_mode == DRAG_ENTRY_RIGHT && g_positions[idx].is_locked)
         {
            g_positions[idx].time_end = t;
            break;
         }

         double new_entry = NormalizeToTick(price);
         if(new_entry <= 0.0) return;

         bool valid = is_long
                      ? (new_entry < g_positions[idx].tp_price && new_entry > g_positions[idx].sl_price)
                      : (new_entry > g_positions[idx].tp_price && new_entry < g_positions[idx].sl_price);
         if(!valid)
         {
            if(!g_drag_warned)
            {
               SetPanelStatus("La apertura no puede cruzar el TP ni el SL.", true);
               g_drag_warned = true;
            }
            return;
         }

         g_positions[idx].entry_price = new_entry;

         if(g_drag_mode == DRAG_ENTRY_LEFT)
            g_positions[idx].time_start = t;
         else
            g_positions[idx].time_end = t;

         break;
      }

      case DRAG_TP_LINE:
      {
         double new_tp = NormalizeToTick(price);
         if(new_tp <= 0.0) return;

         bool valid = is_long ? (new_tp > g_positions[idx].entry_price)
                              : (new_tp < g_positions[idx].entry_price);
         if(!valid)
         {
            if(!g_drag_warned)
            {
               SetPanelStatus("El TP no puede cruzar el precio de entrada.", true);
               g_drag_warned = true;
            }
            return;
         }

         g_positions[idx].tp_price = new_tp;
         break;
      }

      case DRAG_SL_LINE:
      {
         double new_sl = NormalizeToTick(price);
         if(new_sl <= 0.0) return;

         bool valid = is_long ? (new_sl < g_positions[idx].entry_price)
                              : (new_sl > g_positions[idx].entry_price);
         if(!valid)
         {
            if(!g_drag_warned)
            {
               SetPanelStatus("El SL no puede cruzar el precio de entrada.", true);
               g_drag_warned = true;
            }
            return;
         }

         g_positions[idx].sl_price = new_sl;
         break;
      }

      case DRAG_PARTIAL_LINE:
      {
         if(g_drag_stage < 0 || g_drag_stage >= PARTIAL_STAGES) return;

         double new_price = NormalizeToTick(price);
         bool valid = is_long ? (new_price > g_positions[idx].entry_price)
                              : (new_price < g_positions[idx].entry_price);
         if(!valid)
         {
            if(!g_drag_warned)
            {
               SetPanelStatus("El parcial debe quedar en el lado del beneficio.", true);
               g_drag_warned = true;
            }
            return;
         }

         g_positions[idx].partial_is_manual[g_drag_stage]    = true;
         g_positions[idx].partial_manual_price[g_drag_stage] = new_price;
         break;
      }

      case DRAG_ENTIRE_ZONE:
      {
         double shift = NormalizeToTick(delta_price);

         g_positions[idx].entry_price = NormalizeToTick(g_drag_snap_entry + shift);
         g_positions[idx].tp_price    = NormalizeToTick(g_drag_snap_tp    + shift);
         g_positions[idx].sl_price    = NormalizeToTick(g_drag_snap_sl    + shift);

         long time_shift = (long)t - (long)g_drag_ref_time;
         g_positions[idx].time_start = (datetime)((long)g_drag_snap_t1 + time_shift);
         g_positions[idx].time_end   = (datetime)((long)g_drag_snap_t2 + time_shift);
         break;
      }

      case DRAG_LEFT_BORDER:
         g_positions[idx].time_start = t;
         break;

      case DRAG_RIGHT_BORDER:
         g_positions[idx].time_end = t;
         break;

      default:
         break;
   }

   InvalidateZoneVolume(idx);
   UpdatePositionObjects(idx);
   MarkPanelDirty();
   RequestDragRedraw();
}

void FinishZoneDrag()
{
   if(g_drag_mode == DRAG_NONE) return;

   int idx = FindPositionById(g_drag_id);

   if(idx >= 0)
   {
      string err;
      if(!ValidateZone(g_positions[idx], err))
      {
         SetPanelStatus("Posición inválida tras el arrastre (" + err + "); se restauran los niveles.",
                        true);
         CancelZoneDrag(true);
         return;
      }

      if(g_positions[idx].is_executed && g_positions[idx].ticket > 0 &&
         PositionSelectByTicket(g_positions[idx].ticket))
      {
         if(!g_is_primary_instance)
         {
            SetPanelStatus("Modo observador: no se pueden enviar cambios de niveles al servidor.",
                           true);
            CancelZoneDrag(true);
            return;
         }

         string frozen_reason;
         if(PositionIsFrozen(g_positions[idx].ticket, frozen_reason))
         {
            SetPanelStatus("No se pueden mover los niveles ahora: " + frozen_reason + ".", true);
            CancelZoneDrag(true);
            return;
         }

         if(ModifyPositionLevels(g_positions[idx].ticket,
                                 g_positions[idx].sl_price, g_positions[idx].tp_price,
                                 "arrastre manual de niveles"))
         {
            int m = FindManagementIndex(g_positions[idx].ticket);
            if(m >= 0)
            {
               g_management[m].intended_sl = NormalizeToTick(g_positions[idx].sl_price);
               g_management[m].intended_tp = NormalizeToTick(g_positions[idx].tp_price);
            }

            SetPanelStatus("Niveles de la posición actualizados en el servidor.", false);
         }
         else
         {
            SetPanelStatus("El servidor rechazó los nuevos niveles; se restauran.", true);
            CancelZoneDrag(true);
            return;
         }
      }
      else if(!g_positions[idx].is_executed && g_positions[idx].order_ticket > 0 &&
              OrderSelect(g_positions[idx].order_ticket))
      {
         if(!g_is_primary_instance)
         {
            SetPanelStatus("Modo observador: no se pueden enviar cambios de niveles al servidor.",
                           true);
            CancelZoneDrag(true);
            return;
         }

         ulong    pending_ticket  = g_positions[idx].order_ticket;
         double   order_price     = OrderGetDouble(ORDER_PRICE_OPEN);
         datetime order_exp       = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         ENUM_ORDER_TYPE_TIME order_time_type =
            (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);

         double norm_sl = NormalizeToTick(g_positions[idx].sl_price);
         double norm_tp = NormalizeToTick(g_positions[idx].tp_price);

         PrepareTradeObjectForClose();

         if(g_trade_object.OrderModify(pending_ticket, order_price, norm_sl, norm_tp,
                                       order_time_type, order_exp))
         {
            SetPanelStatus("Niveles de la orden pendiente actualizados en el servidor.", false);
         }
         else
         {
            SetPanelStatus("El servidor rechazó los nuevos niveles de la pendiente; se restauran.",
                           true);
            CancelZoneDrag(true);
            return;
         }
      }

      InvalidateZoneVolume(idx);
      UpdatePositionObjects(idx);
   }

   g_drag_mode  = DRAG_NONE;
   g_drag_id    = -1;
   g_drag_stage = -1;

   MarkStateDirty();
   MarkPanelDirty();
   RequestRedraw();
}

//+------------------------------------------------------------------+
//| EVENTOS - RATÓN                                                  |
//+------------------------------------------------------------------+
void HandleMouseMove(int px, int py, int flags)
{
   bool left_down = ((flags & MOUSE_LEFT_BUTTON) != 0);

   if(left_down && !g_left_button_was_down)
   {
      g_mouse_down_px      = px;
      g_mouse_down_py      = py;
      g_drag_start_pending = true;

      if(g_settings_panel_built && SettingsPointInside(px, py))
      {
         if(!IsPanelControlPoint(px, py))
         {
            g_settings_dragging      = true;
            g_settings_drag_offset_x = px - g_settings_x;
            g_settings_drag_offset_y = py - g_settings_y;
         }
      }
      else if(PanelPointInside(px, py))
      {
         if(!IsPanelControlPoint(px, py))
         {
            g_panel_dragging      = true;
            g_panel_drag_offset_x = px - g_panel_x;
            g_panel_drag_offset_y = py - g_panel_y;
         }
      }
   }

   if(g_panel_dragging)
   {
      if(left_down)
      {
         int target_x = px - g_panel_drag_offset_x;
         int target_y = py - g_panel_drag_offset_y;

         if(target_x != g_panel_x || target_y != g_panel_y)
            MovePanelTo(target_x, target_y);
      }
      else
      {
         g_panel_dragging = false;
         FlushPanelLayoutIfPending();
         SaveLiveConfig();
      }

      g_left_button_was_down = left_down;
      return;
   }

   if(g_settings_dragging)
   {
      if(left_down)
      {
         int target_x = px - g_settings_drag_offset_x;
         int target_y = py - g_settings_drag_offset_y;

         if(target_x != g_settings_x || target_y != g_settings_y)
            MoveSettingsTo(target_x, target_y);
      }
      else
      {
         g_settings_dragging = false;
         FlushSettingsLayoutIfPending();
      }

      g_left_button_was_down = left_down;
      return;
   }

   if(left_down && g_drag_start_pending && g_drag_mode == DRAG_NONE &&
      !PointOverAnyPanel(px, py))
   {
      int moved = (int)MathMax(MathAbs(px - g_mouse_down_px), MathAbs(py - g_mouse_down_py));

      if(moved >= MOUSE_DRAG_THRESHOLD_PX)
      {
         long           hit_id;
         ENUM_DRAG_MODE hit_mode;
         int            hit_stage;

         datetime t = 0;
         double   price = 0.0;

         if(ZoneHitTest(g_mouse_down_px, g_mouse_down_py, hit_id, hit_mode, hit_stage) &&
            ChartPointToTimePrice(g_mouse_down_px, g_mouse_down_py, t, price))
         {
            BeginZoneDrag(hit_id, hit_mode, hit_stage, t, price);
         }

         g_drag_start_pending = false;
      }
   }

   if(g_drag_mode != DRAG_NONE)
   {
      if(left_down) UpdateZoneDrag(px, py);
      else          FinishZoneDrag();

      g_left_button_was_down = left_down;
      return;
   }

   if(!left_down && g_left_button_was_down && g_drag_start_pending &&
      !PointOverAnyPanel(px, py))
   {
      int moved = (int)MathMax(MathAbs(px - g_mouse_down_px), MathAbs(py - g_mouse_down_py));

      if(moved < MOUSE_DRAG_THRESHOLD_PX)
      {
         long           hit_id;
         ENUM_DRAG_MODE hit_mode;
         int            hit_stage;

         if(ZoneHitTest(px, py, hit_id, hit_mode, hit_stage)) SelectZone(hit_id);
         else                                                 SelectZone(-1);
      }

      g_drag_start_pending = false;
   }

   if(!left_down)
   {
      static ulong last_hover_ms = 0;
      ulong now = NowMs();

      if(now - last_hover_ms >= (ulong)HOVER_THROTTLE_MS)
      {
         last_hover_ms = now;

         long           hit_id = -1;
         ENUM_DRAG_MODE hit_mode;
         int            hit_stage;

         if(!PointOverAnyPanel(px, py))
            ZoneHitTest(px, py, hit_id, hit_mode, hit_stage);

         if(hit_id != g_hover_id)
         {
            long previous = g_hover_id;
            g_hover_id    = hit_id;

            int prev_idx = FindPositionById(previous);
            if(prev_idx >= 0) UpdatePositionObjects(prev_idx);

            int new_idx = FindPositionById(hit_id);
            if(new_idx >= 0) UpdatePositionObjects(new_idx);

            RequestRedraw();
         }
      }
   }

   g_left_button_was_down = left_down;
}

//+------------------------------------------------------------------+
//| EVENTOS - CLIC EN OBJETOS DEL PANEL                              |
//+------------------------------------------------------------------+
void ReleaseButton(string full_name)
{
   SetObjInt(full_name, OBJPROP_STATE, false);
}

void ToggleSelectedZoneLock()
{
   int idx = GetTargetPositionIndex();
   if(idx < 0)
   {
      SetPanelStatus("No hay posición seleccionada para bloquear o desbloquear.", true);
      return;
   }

   if(g_positions[idx].is_executed || g_positions[idx].order_ticket > 0)
   {
      SetPanelStatus("Las posiciones con orden viva permanecen bloqueadas.", true);
      return;
   }

   g_positions[idx].is_locked = !g_positions[idx].is_locked;

   if(g_positions[idx].is_locked)
   {
      datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(current_bar > 0)
      {
         g_positions[idx].time_start = current_bar;
         g_positions[idx].time_end   = BarTimeAtOffset(current_bar,
                                                        (int)MathMax(1, g_zone_width_bars));
      }
      SynchronizeLockedDraftZones();
   }

   RefreshLockButton();
   UpdatePositionObjects(idx);
   MarkStateDirty();
   MarkPanelDirty();
   RequestRedraw();
}

void DisarmDestructiveButtons()
{
   if(g_flat_arm_until_ms > 0)
   {
      g_flat_arm_until_ms = 0;
      SetObjText(ObjectNameForPanel("BTN_FLAT"), "CERRAR TODO");
   }

   if(g_cancel_arm_until_ms > 0)
   {
      g_cancel_arm_until_ms = 0;
      SetObjText(ObjectNameForPanel("BTN_CANCEL"), "CANCELAR");
   }
}

void HandlePanelButtonClick(string suffix)
{
   if(suffix != "BTN_FLAT"   && g_flat_arm_until_ms   > 0) DisarmDestructiveButtons();
   if(suffix != "BTN_CANCEL" && g_cancel_arm_until_ms > 0) DisarmDestructiveButtons();

   if(suffix == "BTN_GEAR")
   {
      ToggleSettingsPanel();
      return;
   }

   if(suffix == "BTN_LOCK")
   {
      ToggleSelectedZoneLock();
      return;
   }

   if(suffix == "BTN_BUY" || suffix == "BTN_SELL")
   {
      ENUM_PLANNER_POS_TYPE type = (suffix == "BTN_BUY") ? PLANNER_POS_BUY : PLANNER_POS_SELL;
      long id = CreateVisualPosition(type, 0.0, 0);

      if(id > 0)
         SetPanelStatus("Posición creada: arrastre los niveles y pulse EJECUTAR POSICIÓN.", false);

      return;
   }

   if(suffix == "BTN_EXEC")
   {
      ExecuteSelectedOrder();
      return;
   }

   if(suffix == "BTN_CLOSE50" || suffix == "BTN_CLOSE100")
   {
      int idx = GetTargetPositionIndex();
      if(idx < 0)
      {
         SetPanelStatus("Seleccione una posición con operación en mercado para cerrarla.", true);
         return;
      }

      CloseZoneVolume(idx, (suffix == "BTN_CLOSE50") ? 50.0 : 100.0,
                      "cierre manual desde el panel");
      return;
   }

   if(suffix == "BTN_CANCEL")
   {
      ulong now = NowMs();
      int   idx = GetTargetPositionIndex();
      bool  single_target = (idx >= 0 && ZoneHasLivePendingOrder(idx));

      if(g_cancel_arm_until_ms > 0 && now <= g_cancel_arm_until_ms)
      {
         DisarmDestructiveButtons();

         if(single_target)
         {
            if(CancelPendingOrder(g_positions[idx].order_ticket, "cancelación manual"))
               SetPanelStatus("Orden pendiente cancelada.", false);
         }
         else
         {
            CancelAllPendingOrders("cancelación manual desde el panel (confirmada)");
         }
         return;
      }

      g_cancel_arm_until_ms = now + DESTRUCTIVE_CONFIRM_WINDOW_MS;
      SetObjText(ObjectNameForPanel("BTN_CANCEL"), "¿SEGURO? PULSE DE NUEVO");
      SetPanelStatus(single_target
         ? "Pulse CANCELAR otra vez en 4s para cancelar esa orden pendiente."
         : "Pulse CANCELAR otra vez en 4s para cancelar TODAS las pendientes.", true);
      return;
   }

   if(suffix == "BTN_DELETE")
   {
      int idx = GetTargetPositionIndex();
      if(idx < 0)
      {
         SetPanelStatus("No hay posición seleccionada que borrar.", true);
         return;
      }

      if(RemoveVisualPosition(g_positions[idx].id, false))
         SetPanelStatus("Posición borrada.", false);

      return;
   }

   if(suffix == "BTN_FLAT")
   {
      ulong now = NowMs();

      if(g_flat_arm_until_ms > 0 && now <= g_flat_arm_until_ms)
      {
         DisarmDestructiveButtons();
         RequestFlattenAll("solicitud manual desde el panel (confirmada)");
         return;
      }

      g_flat_arm_until_ms = now + DESTRUCTIVE_CONFIRM_WINDOW_MS;
      SetObjText(ObjectNameForPanel("BTN_FLAT"), "¿SEGURO? PULSE DE NUEVO");
      SetPanelStatus("Pulse CERRAR TODO otra vez en 4s para confirmar el cierre total.", true);
      return;
   }

   if(suffix == "BTN_PART")
   {
      g_enable_partials = !g_enable_partials;

      int active = 0;
      for(int s = 0; s < PARTIAL_STAGES; s++)
         if(g_partial_enabled[s]) active++;

      if(g_enable_partials && active == 0)
      {
         g_enable_partials = false;
         SetPanelStatus("Active al menos un tramo parcial (casillas TP1..TP3).", true);
      }
      else
      {
         SetPanelStatus(g_enable_partials ? "Parciales activados para nuevas ejecuciones."
                                          : "Parciales desactivados.", false);
      }

      RefreshManagementToggles();
      SaveLiveConfig();
      MarkPanelDirty();
      return;
   }

   if(suffix == "BTN_BE")
   {
      g_enable_breakeven = !g_enable_breakeven;
      SetPanelStatus(g_enable_breakeven ? "Break-even activado para nuevas ejecuciones."
                                        : "Break-even desactivado.", false);
      RefreshManagementToggles();
      SaveLiveConfig();
      return;
   }

   if(suffix == "BTN_TRAIL")
   {
      g_enable_trailing = !g_enable_trailing;
      SetPanelStatus(g_enable_trailing ? "Trailing activado para nuevas ejecuciones."
                                       : "Trailing desactivado.", false);
      RefreshManagementToggles();
      SaveLiveConfig();
      return;
   }

   if(StringFind(suffix, "CHK_TP") == 0)
   {
      int stage = (int)StringToInteger(StringSubstr(suffix, 6)) - 1;
      if(stage < 0 || stage >= PARTIAL_STAGES) return;

      g_partial_enabled[stage] = !g_partial_enabled[stage];

      RecomputeManagementFlags();
      RecalculateAllPositions();
      SaveLiveConfig();
      return;
   }
}

void HandleSettingsButtonClick(string suffix)
{
   if(suffix == "BTN_X")
   {
      DestroySettingsPanel();
      return;
   }

   if(suffix == "BTN_RESET")
   {
      ApplyInputsToLive();
      ClampLiveSettings();
      RecomputeManagementFlags();
      SaveLiveConfig();

      g_pending_panel_rebuild = true;

      SetSettingsError("");
      SetPanelStatus("Configuración restaurada a los valores de los inputs.", false);
      return;
   }
}

//+------------------------------------------------------------------+
//| EVENTOS - EDICIÓN DE CAMPOS                                      |
//+------------------------------------------------------------------+
void HandlePanelEditEnd(string suffix)
{
   string name = ObjectNameForPanel(suffix);
   string text = ObjectGetString(0, name, OBJPROP_TEXT);

   g_last_edit_ms = NowMs();

   double value = 0.0;
   if(!IsValidDecimal(text, value))
   {
      SetPanelStatus("Valor no numérico; se restaura el anterior.", true);
      UpdatePanelInfo();
      return;
   }

   if(suffix == "EDIT_VOL")
   {
      string err;
      int field = (InpVolumeMode == VOL_FIXED) ? 1 : 0;

      if(!ApplySettingsField(field, value, err))
      {
         SetPanelStatus(err, true);
         g_last_edit_ms = 0;
         UpdatePanelInfo();
         return;
      }

      SetPanelStatus((InpVolumeMode == VOL_FIXED) ? "Lotaje actualizado."
                                                  : "Riesgo por operación actualizado.", false);
      return;
   }

   if(StringFind(suffix, "EDIT_TPM") == 0 || StringFind(suffix, "EDIT_TPP") == 0)
   {
      bool is_mult = (StringFind(suffix, "EDIT_TPM") == 0);
      int  stage   = (int)StringToInteger(StringSubstr(suffix, 8)) - 1;

      if(stage < 0 || stage >= PARTIAL_STAGES) return;

      if(value < 0.0 || value > (is_mult ? 1000.0 : 100.0))
      {
         SetPanelStatus(is_mult ? "Múltiplo de parcial fuera de rango (0 - 1000%)."
                                : "Porcentaje de parcial fuera de rango (0 - 100%).", true);
         g_last_edit_ms = 0;
         RefreshPartialCheckboxes();
         return;
      }

      if(is_mult) g_partial_mult[stage] = value;
      else        g_partial_pct[stage]  = value;

      RecomputeManagementFlags();
      RecalculateAllPositions();
      SaveLiveConfig();

      SetPanelStatus(StringFormat("Parcial %d actualizado: %.0f%% del recorrido, %.0f%% del volumen.",
                                  stage + 1, g_partial_mult[stage], g_partial_pct[stage]), false);
      return;
   }
}

void HandleSettingsEditEnd(string suffix)
{
   if(StringFind(suffix, "EDIT") != 0) return;

   int field = (int)StringToInteger(StringSubstr(suffix, 4));
   if(field < 0 || field >= SETTINGS_FIELDS) return;

   string name = SettingsObjName(suffix);
   string text = ObjectGetString(0, name, OBJPROP_TEXT);

   g_last_edit_ms = NowMs();

   double value = 0.0;
   if(!IsValidDecimal(text, value))
   {
      SetSettingsError(g_settings_labels[field] + ": valor no numérico.");
      SetObjText(name, DoubleToString(SettingsFieldValue(field), SettingsFieldDecimals(field)));
      return;
   }

   string err;
   if(!ApplySettingsField(field, value, err))
   {
      SetSettingsError(err);
      SetObjText(name, DoubleToString(SettingsFieldValue(field), SettingsFieldDecimals(field)));
      return;
   }

   SetSettingsError("");
   SetObjText(name, DoubleToString(SettingsFieldValue(field), SettingsFieldDecimals(field)));
   SetPanelStatus(g_settings_labels[field] + " actualizado.", false);
}

//+------------------------------------------------------------------+
//| EVENTOS - TECLADO                                                |
//+------------------------------------------------------------------+
void HandleKeyDown(long key_code)
{
   if(key_code != KEY_DELETE) return;

   if(g_edit_focus_active) return;

   if(NowMs() - g_last_edit_ms < (ulong)DELETE_KEY_BLIND_MS) return;

   int idx = GetTargetPositionIndex();
   if(idx < 0) return;

   if(RemoveVisualPosition(g_positions[idx].id, false))
      SetPanelStatus("Posición borrada con la tecla Supr.", false);
}

//+------------------------------------------------------------------+
//| EVENTOS - DESPACHADOR PRINCIPAL                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      HandleMouseMove((int)lparam, (int)dparam, (int)StringToInteger(sparam));
      return;
   }

   if(id == CHARTEVENT_CHART_CHANGE)
   {
      InvalidatePricePerPixel();

      double zoom_before = g_panel_zoom;
      double max_zoom_now = MaxPanelZoomForChartHeight();
      if(g_panel_zoom > max_zoom_now)
      {
         g_panel_zoom = MathMax(0.7, max_zoom_now);
         if(g_settings_panel_open) g_pending_panel_rebuild = true;
      }

      if(g_settings_panel_open) MoveSettingsTo(g_settings_x, g_settings_y);

      ulong now = NowMs();
      if(now - g_last_chart_change_ms < (ulong)CHART_CHANGE_THROTTLE_MS)
      {
         g_chart_change_pending = true;
         return;
      }

      g_last_chart_change_ms = now;
      g_chart_change_pending = false;

      RecalculateAllPositions();
      return;
   }

   if(id == CHARTEVENT_KEYDOWN)
   {
      HandleKeyDown(lparam);
      return;
   }

   if(id == CHARTEVENT_CLICK)
   {
      g_edit_focus_active = false;
      return;
   }

   if(g_suppress_object_events > 0) return;

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      ENUM_OBJECT clicked_type = (ENUM_OBJECT)ObjectGetInteger(0, sparam, OBJPROP_TYPE);
      g_edit_focus_active = (clicked_type == OBJ_EDIT);

      string panel_prefix = InpObjectPrefix + "#PANEL#";
      string cfg_prefix   = InpObjectPrefix + "#CFG#";

      if(StringFind(sparam, panel_prefix) == 0)
      {
         string suffix = StringSubstr(sparam, StringLen(panel_prefix));
         ReleaseButton(sparam);
         HandlePanelButtonClick(suffix);
         UpdatePanelInfo();
         RequestRedraw();
         return;
      }

      if(StringFind(sparam, cfg_prefix) == 0)
      {
         string suffix = StringSubstr(sparam, StringLen(cfg_prefix));
         ReleaseButton(sparam);
         HandleSettingsButtonClick(suffix);
         RequestRedraw();
         return;
      }

      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      g_edit_focus_active = false;

      string panel_prefix = InpObjectPrefix + "#PANEL#";
      string cfg_prefix   = InpObjectPrefix + "#CFG#";

      if(StringFind(sparam, panel_prefix) == 0)
      {
         HandlePanelEditEnd(StringSubstr(sparam, StringLen(panel_prefix)));
         UpdatePanelInfo();
         RequestRedraw();
         return;
      }

      if(StringFind(sparam, cfg_prefix) == 0)
      {
         HandleSettingsEditEnd(StringSubstr(sparam, StringLen(cfg_prefix)));
         RequestRedraw();
         return;
      }

      return;
   }

   if(id == CHARTEVENT_OBJECT_DELETE)
   {
      if(StringFind(sparam, InpObjectPrefix + "#PANEL#") == 0)
      {
         g_pending_panel_rebuild = true;
         return;
      }

      if(StringFind(sparam, InpObjectPrefix + "#" + _Symbol + "#") == 0)
      {
         g_pending_zone_rebuild = true;
         return;
      }

      return;
   }

   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      if(StringFind(sparam, InpObjectPrefix + "#" + _Symbol + "#") == 0)
      {
         g_pending_zone_rebuild = true;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| ==== PARTE 4/4 ====                                              |
//| Ejecución con reintentos, gestión automática, verificación de    |
//| niveles, límites de cuenta, persistencia, bloqueo de instancia   |
//| y manejadores de eventos del terminal.                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| PROTOTIPOS INTERNOS DE ESTA PARTE                                |
//+------------------------------------------------------------------+
void   ProcessOrderPlan();
void   AbortOrderPlan(string reason, bool problem);
bool   IsRetryableRetcode(uint retcode);
bool   IsSuccessfulTradeRetcode(uint retcode);
void   RecordManagementTradeResult(ulong ticket, bool success);
void   ManageOpenPositions();
void   ProcessFlatten();
void   CheckAccountLimits();
void   UpdateLimitBaselines(bool force);
void   AdoptOrphanPositions();
void   VerifyProtectiveLevels();
void   HideNativeTradeLevels();
void   ProcessPendingCancels(); // M-1: cola de cancelaciones diferidas (OnTick/OnTimer)
void   WriteInstanceHeartbeat();
void   LoadPositionsState();
void   LoadSavedConfig();

//+------------------------------------------------------------------+
//| REGISTRO Y NOTIFICACIONES                                        |
//+------------------------------------------------------------------+
void LogExecution(string message, bool is_problem)
{
   PrintFormat("%s: %s%s", APP_NAME, is_problem ? "AVISO — " : "", message);

   if(is_problem && InpEnablePushNotifications && !IsTesterContext())
      SendNotification(StringFormat("%s %s: %s", APP_NAME, _Symbol, message));
}

//+------------------------------------------------------------------+
//| PERSISTENCIA - ALMACÉN CLAVE/VALOR DE CONFIGURACIÓN              |
//+------------------------------------------------------------------+
void CfgClear()
{
   for(int i = 0; i < CFG_MAX_KEYS; i++)
   {
      g_cfg_key[i]  = "";
      g_cfg_val[i]  = 0.0;
      g_cfg_used[i] = false;
   }
   g_cfg_count = 0;
}

void CfgSet(string key, double value)
{
   for(int i = 0; i < g_cfg_count; i++)
      if(g_cfg_key[i] == key) { g_cfg_val[i] = value; return; }

   if(g_cfg_count >= CFG_MAX_KEYS) return;

   g_cfg_key[g_cfg_count]  = key;
   g_cfg_val[g_cfg_count]  = value;
   g_cfg_used[g_cfg_count] = true;
   g_cfg_count++;
}

double CfgGet(string key, double fallback)
{
   for(int i = 0; i < g_cfg_count; i++)
      if(g_cfg_key[i] == key) return g_cfg_val[i];

   return fallback;
}

string ConfigFileName()
{
   return APP_NAME + "_CFG_" + InstanceFileToken() + ".csv";
}

string StateFileName()
{
   return APP_NAME + "_STATE_" + InstanceFileToken() + ".csv";
}

void ClearPersistedPositionsState()
{
   string fname = StateFileName();
   if(FileIsExist(fname, FILE_COMMON))
   {
      if(FileDelete(fname, FILE_COMMON))
         PrintFormat("%s: estado de posiciones eliminado (%s) al quitar el EA.",
                     APP_NAME, fname);
      else
         PrintFormat("%s: no se pudo eliminar el archivo de estado %s (error %d).",
                     APP_NAME, fname, GetLastError());
   }
}

string LockFileName()
{
   return APP_NAME + "_LOCK_" + InstanceFileToken() + ".txt";
}

void SaveLiveConfig()
{
   if(IsTesterContext()) return;

   int h = FileOpen(ConfigFileName(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h, CFG_HEADER_V3 + "\n");
   FileWriteString(h, "volume="        + DoubleToString(g_volume, 4) + "\n");
   FileWriteString(h, "risk_pct="      + DoubleToString(EffectiveRiskPercent(), 4) + "\n");
   FileWriteString(h, "tp_ticks="      + IntegerToString(g_tp_ticks) + "\n");
   FileWriteString(h, "sl_ticks="      + IntegerToString(g_sl_ticks) + "\n");
   FileWriteString(h, "zone_bars="     + IntegerToString(g_zone_width_bars) + "\n");
   FileWriteString(h, "transparency="  + IntegerToString(g_transparency) + "\n");
   FileWriteString(h, "max_dev="       + IntegerToString(g_max_deviation) + "\n");
   FileWriteString(h, "max_retries="   + IntegerToString(g_max_retries) + "\n");
   FileWriteString(h, "backoff="       + IntegerToString(g_backoff_base) + "\n");
   FileWriteString(h, "be_offset="     + IntegerToString(g_be_offset_ticks) + "\n");
   FileWriteString(h, "be_start_r="    + DoubleToString(g_be_start_r, 4) + "\n");
   FileWriteString(h, "trail_start_r=" + DoubleToString(g_trailing_start_r, 4) + "\n");
   FileWriteString(h, "trail_ticks="   + IntegerToString(g_trailing_ticks) + "\n");
   FileWriteString(h, "trail_step="    + IntegerToString(g_trailing_step_ticks) + "\n");
   FileWriteString(h, "trail_atr_mult="+ DoubleToString(g_trailing_atr_multiplier, 4) + "\n");
   FileWriteString(h, "panel_zoom="    + DoubleToString(g_panel_zoom, 4) + "\n");
   FileWriteString(h, "panel_x="       + IntegerToString(g_panel_x) + "\n");
   FileWriteString(h, "panel_y="       + IntegerToString(g_panel_y) + "\n");
   FileWriteString(h, "partials_on="   + IntegerToString(g_enable_partials  ? 1 : 0) + "\n");
   FileWriteString(h, "be_on="         + IntegerToString(g_enable_breakeven ? 1 : 0) + "\n");
   FileWriteString(h, "trail_on="      + IntegerToString(g_enable_trailing  ? 1 : 0) + "\n");

   FileWriteString(h, "font_size="     + IntegerToString(g_font_size_stats) + "\n");
   FileWriteString(h, "line_width="    + IntegerToString(g_line_width) + "\n");
   FileWriteString(h, "daily_loss="    + DoubleToString(g_daily_loss_limit, 4) + "\n");
   FileWriteString(h, "weekly_loss="   + DoubleToString(g_weekly_loss_limit, 4) + "\n");
   FileWriteString(h, "entry_tol="     + DoubleToString(g_entry_tolerance_ticks, 4) + "\n");
   FileWriteString(h, "mgmt_interval=" + IntegerToString(g_management_interval) + "\n");

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      string tag = IntegerToString(s + 1);
      FileWriteString(h, "p" + tag + "_on="   + IntegerToString(g_partial_enabled[s] ? 1 : 0) + "\n");
      FileWriteString(h, "p" + tag + "_mult=" + DoubleToString(g_partial_mult[s], 4) + "\n");
      FileWriteString(h, "p" + tag + "_pct="  + DoubleToString(g_partial_pct[s],  4) + "\n");
   }

   FileClose(h);
}

void LoadSavedConfig()
{
   if(!InpLoadSavedConfig || IsTesterContext()) return;

   int h = FileOpen(ConfigFileName(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) return;

   string header = FileReadString(h);
   StringTrimRight(header);

   if(header != CFG_HEADER_V3 && header != CFG_HEADER_V2)
   {
      FileClose(h);
      PrintFormat("%s: el archivo de configuración tiene una versión desconocida; se ignora.",
                  APP_NAME);
      return;
   }

   CfgClear();

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line == "") continue;

      int sep = StringFind(line, "=");
      if(sep <= 0) continue;

      string key  = StringSubstr(line, 0, sep);
      string text = StringSubstr(line, sep + 1);

      double value = 0.0;
      if(!IsValidSignedDecimal(text, value)) continue;

      CfgSet(key, value);
   }

   FileClose(h);

   g_volume                  = CfgGet("volume",        g_volume);
   g_effective_risk_percent  = CfgGet("risk_pct",      EffectiveRiskPercent());
   g_tp_ticks                = (int)CfgGet("tp_ticks", g_tp_ticks);
   g_sl_ticks                = (int)CfgGet("sl_ticks", g_sl_ticks);
   g_zone_width_bars         = (int)CfgGet("zone_bars",g_zone_width_bars);
   g_transparency            = (int)CfgGet("transparency", g_transparency);
   g_max_deviation           = (int)CfgGet("max_dev",  g_max_deviation);
   g_max_retries             = (int)CfgGet("max_retries", g_max_retries);
   g_backoff_base            = (int)CfgGet("backoff",  g_backoff_base);
   g_be_offset_ticks         = (int)CfgGet("be_offset",g_be_offset_ticks);
   g_be_start_r              = CfgGet("be_start_r",    g_be_start_r);
   g_trailing_start_r        = CfgGet("trail_start_r", g_trailing_start_r);
   g_trailing_ticks          = (int)CfgGet("trail_ticks", g_trailing_ticks);
   g_trailing_step_ticks     = (int)CfgGet("trail_step",  g_trailing_step_ticks);
   g_trailing_atr_multiplier = CfgGet("trail_atr_mult",   g_trailing_atr_multiplier);
   g_panel_zoom              = CfgGet("panel_zoom",  g_panel_zoom);
   g_panel_x                 = (int)CfgGet("panel_x", g_panel_x);
   g_panel_y                 = (int)CfgGet("panel_y", g_panel_y);

   g_enable_partials  = (CfgGet("partials_on", g_enable_partials  ? 1 : 0) > 0.5);
   g_enable_breakeven = (CfgGet("be_on",       g_enable_breakeven ? 1 : 0) > 0.5);
   g_enable_trailing  = (CfgGet("trail_on",    g_enable_trailing  ? 1 : 0) > 0.5);

   g_font_size_stats      = (int)CfgGet("font_size",     g_font_size_stats);
   g_line_width            = (int)CfgGet("line_width",    g_line_width);
   g_daily_loss_limit      = CfgGet("daily_loss",         g_daily_loss_limit);
   g_weekly_loss_limit     = CfgGet("weekly_loss",        g_weekly_loss_limit);
   g_entry_tolerance_ticks = CfgGet("entry_tol",          g_entry_tolerance_ticks);
   g_management_interval   = (int)CfgGet("mgmt_interval", g_management_interval);

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      string tag = IntegerToString(s + 1);
      g_partial_enabled[s] = (CfgGet("p" + tag + "_on",
                                     g_partial_enabled[s] ? 1 : 0) > 0.5);
      g_partial_mult[s]    = CfgGet("p" + tag + "_mult", g_partial_mult[s]);
      g_partial_pct[s]     = CfgGet("p" + tag + "_pct",  g_partial_pct[s]);
   }

   PrintFormat("%s: configuración guardada cargada desde %s.", APP_NAME, ConfigFileName());

   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   if(chart_w > 0 && chart_h > 0)
   {
      int min_x = S(PANEL_MARGIN);
      int max_x = (int)MathMax(min_x, chart_w - S(g_panel_width));
      int min_y = S(PanelHeaderHeight());
      int max_y = (int)MathMax(min_y, chart_h - S(PANEL_HEIGHT) + S(PanelHeaderHeight()));

      g_panel_x = (int)MathMax(min_x, MathMin(max_x, g_panel_x));
      g_panel_y = (int)MathMax(min_y, MathMin(max_y, g_panel_y));
   }
}

//+------------------------------------------------------------------+
//| PERSISTENCIA - SERIALIZACIÓN DEL ESTADO                          |
//| (hash de integridad + construcción del payload V8)               |
//+------------------------------------------------------------------+
void MarkStateDirty()
{
   g_state_dirty = true;
}

ulong SimpleHash(string s)
{
   ulong h = 1469598103934665603;
   int   n = StringLen(s);

   for(int i = 0; i < n; i++)
   {
      h ^= (ulong)StringGetCharacter(s, i);
      h *= 1099511628211;
   }

   return h;
}

string BuildStatePayload()
{
   string out = STATE_HEADER_V8 + "\n";

   // #3: persistencia de los baselines de límites diario/semanal. Sin esto,
   // tras reiniciar el terminal UpdateLimitBaselines(true) recalculaba el
   // baseline con la equity actual y "olvidaba" las pérdidas ya materializadas
   // en el día/semana, permitiendo volver a operar tras tocar un límite.
   out += StringFormat("L;%I64d;%.2f;%I64d;%.2f\n",
                       (long)g_date_day_start,  g_balance_day_start,
                       (long)g_date_week_start, g_balance_week_start);

   out += "C;" + IntegerToString(g_position_counter) + ";" +
          IntegerToString(g_selected_id) + "\n";

   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      SVisualPosition p = g_positions[i];

      if(p.id < 0) continue;

      out += StringFormat("Z;%I64d;%d;%s;%s;%s;%I64d;%I64d;%d;%d;%d;%I64d;%I64u;%I64u",
                          p.id, (int)p.type,
                          DoubleToString(p.entry_price, _Digits),
                          DoubleToString(p.tp_price,    _Digits),
                          DoubleToString(p.sl_price,    _Digits),
                          (long)p.time_start, (long)p.time_end,
                          p.is_locked   ? 1 : 0,
                          p.is_executed ? 1 : 0,
                          p.is_closed   ? 1 : 0,
                          (long)p.closed_at,
                          p.ticket, p.order_ticket);

      for(int s = 0; s < PARTIAL_STAGES; s++)
         out += StringFormat(";%d;%s", p.partial_is_manual[s] ? 1 : 0,
                             DoubleToString(p.partial_manual_price[s], _Digits));

      out += "\n";
   }

   for(int m = 0; m < ArraySize(g_management); m++)
   {
      SPositionManagement r = g_management[m];

      out += StringFormat("M;%I64u;%I64d;%s;%s;%s;%s;%d;%d;%d;%d;%s;%d;%d;%d;%s;%d;%d",
                          r.ticket, r.order_type,
                          DoubleToString(r.volume_original, 4),
                          DoubleToString(r.entry_price,   _Digits),
                          DoubleToString(r.risk_distance, _Digits),
                          DoubleToString(r.target_distance, _Digits),
                          r.plan_partials_on ? 1 : 0,
                          r.plan_be_on       ? 1 : 0,
                          r.plan_be_stage,
                          r.plan_be_offset_ticks,
                          DoubleToString(r.plan_be_start_r, 4),
                          r.plan_be_cover_costs ? 1 : 0,
                          r.plan_trail_on ? 1 : 0,
                          r.plan_trail_method,
                          DoubleToString(r.plan_trail_start_r, 4),
                          r.breakeven_done  ? 1 : 0,
                          r.trailing_active ? 1 : 0);

      for(int s = 0; s < PARTIAL_STAGES; s++)
         out += StringFormat(";%d;%s;%s;%d;%d",
                             r.plan_stage_active[s] ? 1 : 0,
                             DoubleToString(r.plan_stage_price[s], _Digits),
                             DoubleToString(r.plan_stage_pct[s], 2),
                             r.partial_resolved[s] ? 1 : 0,
                             r.partial_executed[s] ? 1 : 0);

      out += StringFormat(";%s;%s;%d;%d;%d;%s\n",
                          DoubleToString(r.intended_sl, _Digits),
                          DoubleToString(r.intended_tp, _Digits),
                          r.levels_pending ? 1 : 0,
                          r.plan_trail_ticks,
                          r.plan_trail_step_ticks,
                          DoubleToString(r.plan_trail_atr_mult, 4));
   }

   return out;
}

//+------------------------------------------------------------------+
//| PERSISTENCIA - ESCRITURA ATÓMICA DEL ESTADO                      |
//| (vuelco a .tmp + FileMove REWRITE para sobrevivir cortes)        |
//+------------------------------------------------------------------+
void SavePositionsState()
{
   if(IsTesterContext()) return;
   if(!g_is_primary_instance) return;

   string payload = BuildStatePayload();
   ulong  hash    = SimpleHash(payload);

   if(hash == g_state_chk)
   {
      g_state_dirty = false;
      return;
   }

   // #4: escritura atómica — volcar a un .tmp, cerrar, y reemplazar el
   // archivo definitivo con FileMove(REWRITE). Si el terminal se cae a mitad
   // de la escritura, el estado anterior queda intacto.
   string final_name = StateFileName();
   string tmp_name   = final_name + ".tmp";

   int h = FileOpen(tmp_name, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("%s: no se pudo escribir el estado temporal en %s (error %d).",
                  APP_NAME, tmp_name, GetLastError());
      return;
   }

   FileWriteString(h, payload);
   FileFlush(h);
   FileClose(h);

   if(!FileMove(tmp_name, FILE_COMMON, final_name, FILE_COMMON | FILE_REWRITE))
   {
      PrintFormat("%s: FileMove del estado (%s -> %s) falló (error %d); reintento directo.",
                  APP_NAME, tmp_name, final_name, GetLastError());
      int h2 = FileOpen(final_name, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(h2 == INVALID_HANDLE)
      {
         PrintFormat("%s: no se pudo escribir el estado en %s (error %d).",
                     APP_NAME, final_name, GetLastError());
         return;
      }
      FileWriteString(h2, payload);
      FileClose(h2);
   }

   g_state_chk   = hash;
   g_state_dirty = false;
}

//+------------------------------------------------------------------+
//| PERSISTENCIA - CARGA Y VALIDACIÓN DEL ESTADO                     |
//| (compatibilidad V5/V6/V7 + restauración de gestión)              |
//+------------------------------------------------------------------+
void LoadPositionsState()
{
   if(IsTesterContext()) return;

   int h = FileOpen(StateFileName(), FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) return;

   const ulong MAX_STATE_FILE_BYTES = 10 * 1024 * 1024;
   ulong file_size = FileSize(h);
   if(file_size > MAX_STATE_FILE_BYTES)
   {
      FileClose(h);
      PrintFormat("%s: el archivo de estado %s pesa %I64u bytes (supera el límite de " +
                  "seguridad de %I64u). Parece corrupto; se descarta y se arranca SIN " +
                  "posiciones guardadas. Revisa o borra manualmente ese archivo si quieres.",
                  APP_NAME, StateFileName(), file_size, MAX_STATE_FILE_BYTES);
      return;
   }

   string header = FileReadString(h);
   StringTrimRight(header);

   if(header == STATE_HEADER_V5)
   {
      FileClose(h);
      PrintFormat("%s: el archivo de estado es de la versión V5, que ya no se admite (no hay " +
                  "migración fiable columna a columna; interpretarlo con el layout V6/V7 " +
                  "corrompería precios, tickets y banderas silenciosamente). Se ignora y se " +
                  "arranca sin posiciones guardadas.", APP_NAME);
      return;
   }

   if(header != STATE_HEADER_V8 && header != STATE_HEADER_V7 && header != STATE_HEADER_V6)
   {
      FileClose(h);
      PrintFormat("%s: estado guardado con versión desconocida (%s); se ignora.",
                  APP_NAME, header);
      return;
   }

   bool is_legacy_v6 = (header == STATE_HEADER_V6);

   ArrayResize(g_positions, 0);
   ArrayResize(g_management, 0);

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line == "") continue;

      string f[];
      int    n = StringSplit(line, ';', f);
      if(n <= 1) continue;

      if(f[0] == "L" && n >= 5 && header == STATE_HEADER_V8)
      {
         // #3: baselines de límites persistidos. Se validan contra el inicio
         // actual del día/semana usando las MISMAS funciones con las que se
         // escribieron (DayStartWithResetHour/WeekStartWithResetHour, tiempo
         // del servidor), para que la comparación sea exacta.
         datetime now          = TimeCurrent();
         datetime day_start_now  = DayStartWithResetHour(now);
         datetime week_start_now = WeekStartWithResetHour(now);

         datetime d_day  = (datetime)StringToInteger(f[1]);
         double   b_day  = StringToDouble(f[2]);
         datetime d_week = (datetime)StringToInteger(f[3]);
         double   b_week = StringToDouble(f[4]);

         bool day_ok  = (d_day  == day_start_now  && b_day  > 0.0);
         bool week_ok = (d_week == week_start_now && b_week > 0.0);

         if(day_ok && week_ok)
         {
            g_balance_day_start        = b_day;
            g_date_day_start           = d_day;
            g_balance_week_start       = b_week;
            g_date_week_start          = d_week;
            g_limit_baseline_restored  = true;
            PrintFormat("%s: baselines de límites restaurados del estado (día %s %.2f / semana %s %.2f).",
                        APP_NAME, TimeToString(d_day, TIME_DATE|TIME_MINUTES), b_day,
                        TimeToString(d_week, TIME_DATE), b_week);
         }
         else
         {
            PrintFormat("%s: los baselines guardados no corresponden al día/semana actual " +
                        "(o eran inválidos); se recalcularán en UpdateLimitBaselines.", APP_NAME);
         }
         continue;
      }

      if(f[0] == "C" && n >= 3)
      {
         g_position_counter = (long)StringToInteger(f[1]);
         g_selected_id      = (long)StringToInteger(f[2]);
         continue;
      }

      if(f[0] == "Z" && n >= 14)
      {
         long parsed_id = (long)StringToInteger(f[1]);

         if(parsed_id <= 0 || FindPositionById(parsed_id) >= 0)
            continue;

         SVisualPosition p;
         ResetZoneStruct(p);

         p.id           = parsed_id;
         p.type         = (ENUM_PLANNER_POS_TYPE)(int)StringToInteger(f[2]);
         p.entry_price  = StringToDouble(f[3]);
         p.tp_price     = StringToDouble(f[4]);
         p.sl_price     = StringToDouble(f[5]);
         p.time_start   = (datetime)StringToInteger(f[6]);
         p.time_end     = (datetime)StringToInteger(f[7]);
         p.is_locked    = (StringToInteger(f[8])  != 0);
         p.is_executed  = (StringToInteger(f[9])  != 0);
         p.is_closed    = (StringToInteger(f[10]) != 0);
         p.closed_at    = (datetime)StringToInteger(f[11]);
         p.ticket       = (ulong)StringToInteger(f[12]);
         p.order_ticket = (ulong)StringToInteger(f[13]);

         for(int s = 0; s < PARTIAL_STAGES; s++)
         {
            int base = 14 + s * 2;
            if(base + 1 >= n) break;

            p.partial_is_manual[s]    = (StringToInteger(f[base]) != 0);
            p.partial_manual_price[s] = StringToDouble(f[base + 1]);
         }

         if(p.is_executed && p.ticket > 0 && !PositionSelectByTicket(p.ticket))
         {
            p.is_executed = false;
            p.is_closed   = true;
            if(p.closed_at <= 0) p.closed_at = TimeCurrent();
         }

         if(p.order_ticket > 0 && !OrderSelect(p.order_ticket))
            p.order_ticket = 0;

         int idx = ArraySize(g_positions);
         if(EnsureArrayCapacity(g_positions, idx + 1) < idx + 1) break;

         g_positions[idx] = p;
         continue;
      }

      if(f[0] == "M" && n >= 18)
      {
         ulong ticket = (ulong)StringToInteger(f[1]);
         if(!PositionSelectByTicket(ticket)) continue;
         if(!PositionBelongsToEA(ticket))    continue;

         SPositionManagement r;
         ResetManagementRecord(r);

         r.ticket               = ticket;
         r.order_type           = (long)StringToInteger(f[2]);
         r.volume_original      = StringToDouble(f[3]);
         r.entry_price          = StringToDouble(f[4]);
         r.risk_distance        = StringToDouble(f[5]);
         r.target_distance      = StringToDouble(f[6]);
         r.plan_partials_on     = (StringToInteger(f[7])  != 0);
         r.plan_be_on           = (StringToInteger(f[8])  != 0);
         r.plan_be_stage        = (int)StringToInteger(f[9]);
         r.plan_be_offset_ticks = (int)StringToInteger(f[10]);
         r.plan_be_start_r      = StringToDouble(f[11]);
         r.plan_be_cover_costs  = (StringToInteger(f[12]) != 0);
         r.plan_trail_on        = (StringToInteger(f[13]) != 0);
         r.plan_trail_method    = (int)StringToInteger(f[14]);
         r.plan_trail_start_r   = StringToDouble(f[15]);
         r.breakeven_done       = (StringToInteger(f[16]) != 0);
         r.trailing_active      = (StringToInteger(f[17]) != 0);

         int cursor = 18;
         for(int s = 0; s < PARTIAL_STAGES; s++)
         {
            if(cursor + 4 >= n) break;

            r.plan_stage_active[s] = (StringToInteger(f[cursor])     != 0);
            r.plan_stage_price[s]  = StringToDouble(f[cursor + 1]);
            r.plan_stage_pct[s]    = StringToDouble(f[cursor + 2]);
            r.partial_resolved[s]  = (StringToInteger(f[cursor + 3]) != 0);
            r.partial_executed[s]  = (StringToInteger(f[cursor + 4]) != 0);

            cursor += 5;
         }

         if(cursor + 2 < n)
         {
            r.intended_sl    = StringToDouble(f[cursor]);
            r.intended_tp    = StringToDouble(f[cursor + 1]);
            r.levels_pending = (StringToInteger(f[cursor + 2]) != 0);
            cursor += 3;
         }

         if(!is_legacy_v6 && cursor + 2 < n)
         {
            r.plan_trail_ticks      = (int)StringToInteger(f[cursor]);
            r.plan_trail_step_ticks = (int)StringToInteger(f[cursor + 1]);
            r.plan_trail_atr_mult   = StringToDouble(f[cursor + 2]);
         }
         else
         {
            r.plan_trail_ticks      = (int)MathMax(1, g_trailing_ticks);
            r.plan_trail_step_ticks = (int)MathMax(1, g_trailing_step_ticks);
            r.plan_trail_atr_mult   = MathMax(0.1, g_trailing_atr_multiplier);

            if(is_legacy_v6 && r.plan_trail_on)
               PrintFormat("%s: AVISO — el ticket %I64u viene de un estado V6 (formato antiguo, " +
                           "sin trailing congelado); usará los parámetros de trailing ACTUALES, " +
                           "que pueden no coincidir con los planeados originalmente.",
                           APP_NAME, r.ticket);
         }

         int mi = ArraySize(g_management);
         if(EnsureArrayCapacity(g_management, mi + 1) < mi + 1) break;

         g_management[mi] = r;
      }
   }

   FileClose(h);

   PurgeOldClosedZones();
   InvalidateAllZoneVolumes();

   PrintFormat("%s: estado restaurado — %d posiciones, %d en gestión.",
               APP_NAME, ArraySize(g_positions), ArraySize(g_management));
}

//+------------------------------------------------------------------+
//| PERSISTENCIA - LOCK DE INSTANCIA                                 |
//| (adquisición, heartbeat y revalidación anti doble-primaria)      |
//+------------------------------------------------------------------+
// Lee los campos persistentes del archivo de lock. NOTA DE DISEÑO: el campo
// "written" SIEMPRE es el último que la primaria escribe en el archivo (ver
// WriteInstanceHeartbeat). Por eso puede usarse como marca de escritura
// COMPLETA: si tras una lectura no aparece, la otra instancia interrumpió su
// escritura entre medias y ese heartbeat NO debe considerarse válido.
bool ReadLockFileFields(string &out_uid, string &out_heartbeat, string &out_written)
{
   out_uid       = "";
   out_heartbeat = "";
   out_written   = "";

   int h = FileOpen(LockFileName(),
                    FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON |
                    FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return false;

   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      StringTrimLeft(line);
      StringTrimRight(line);

      if(out_uid == "" && StringFind(line, "uid=") == 0)
         out_uid = StringSubstr(line, 4);

      if(StringFind(line, "heartbeat=") == 0)
         out_heartbeat = StringSubstr(line, StringLen("heartbeat="));

      if(StringFind(line, "written=") == 0)
      {
         out_written = StringSubstr(line, StringLen("written="));
         break;
      }
   }

   FileClose(h);
   return true;
}

// Versión de conveniencia para los consumidores que no necesitan distinguir
// heartbeat de marca de finalización.
bool ReadLockFileFields(string &out_uid, string &out_heartbeat)
{
   string written;
   return ReadLockFileFields(out_uid, out_heartbeat, written);
}

// Valida un registro de lock leído del disco:
//  - uid numérico (> 0),
//  - heartbeat parseable (> 0),
//  - marca de escritura completa ("written") presente y coincidente con el
//    heartbeat (descarta lecturas parciales de una escritura ajena en curso).
// Devuelve además el momento del heartbeat en hb_out.
bool ParseValidatedLockRecord(string uid_text, string hb_text, string written_text,
                              long &out_uid, datetime &hb_out)
{
   out_uid = 0;
   hb_out  = 0;

   if(uid_text == "" || hb_text == "" || written_text == "") return false;

   long uid = (long)StringToInteger(uid_text);
   if(uid <= 0) return false;

   datetime hb = StringToTime(hb_text);
   if(hb <= 0) return false;

   // "written" es lo último que se escribe: si falta o difiere del heartbeat,
   // la escritura quedó truncada por una lectura/escritura concurrente.
   if(written_text != hb_text) return false;

   out_uid = uid;
   hb_out  = hb;
   return true;
}

bool IsLockFileHeldByLiveInstance()
{
   string uid_text, hb_text, written_text;
   if(!ReadLockFileFields(uid_text, hb_text, written_text)) return false;

   long     uid;
   datetime hb;
   if(!ParseValidatedLockRecord(uid_text, hb_text, written_text, uid, hb)) return false;

   // Ventana de obsolescencia: 6 ciclos de heartbeat (≈30 s), coherente con
   // VerifyLockOwnership y con INSTANCE_HB_STALE_SEC.
   return (TimeCurrent() - hb) <= INSTANCE_HB_STALE_SEC;
}

bool AcquireInstanceLock()
{
   g_instance_uid    = (long)ChartID();
   g_lock_attempts   = 0;
   g_lock_owner_verified = false;

   if(IsTesterContext())
   {
      g_is_primary_instance = true;
      g_lock_owner_verified = true;
      return true;
   }

   ResetLastError();

   g_lock_file_handle = FileOpen(LockFileName(),
                                 FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);

   if(g_lock_file_handle != INVALID_HANDLE)
   {
      // C-3 (primera capa): FileOpen(FILE_WRITE) sin flags SHARE otorga
      // EXCLUSIVIDAD a nivel del sandbox de terminal_common: cualquier otra
      // instancia (aunque sea de otro terminal instalado en la máquina)
      // recibirá ACCESS_DENIED mientras este handle permanezca abierto. Es la
      // primera línea de defensa anti doble-primaria; las otras dos capas son:
      //   - revalidación post-escritura aquí mismo (ventana de solapamiento en
      //     el instante exacto del arranque simultáneo),
      //   - VerifyLockOwnership periódico + degradación determinista por uid
      //     (recupera el orden correcto si aun así hubiera dos primarias).
      // El handle debe mantenerse ABIERTO durante toda la vida de la primaria:
      // cerrarlo dejaría el archivo libre para otra instancia.
      WriteInstanceHeartbeat();

      string uid_text, hb_text, written_text;
      if(ReadLockFileFields(uid_text, hb_text, written_text))
      {
         long     other_uid;
         datetime other_hb;
         bool valid_other = ParseValidatedLockRecord(uid_text, hb_text, written_text,
                                                     other_uid, other_hb);

         if(valid_other && other_uid != g_instance_uid &&
            (TimeCurrent() - other_hb) <= INSTANCE_HB_STALE_SEC)
         {
            FileClose(g_lock_file_handle);
            g_lock_file_handle = INVALID_HANDLE;

            g_is_primary_instance   = false;
            g_lock_owner_verified   = false;
            g_next_lock_retry_ms    = NowMs() + (ulong)INSTANCE_LOCK_RETRY_MS;

            PrintFormat("%s: AVISO — dos instancias abrieron el bloqueo casi a la vez; " +
                        "el chart %I64d escribió un heartbeat vigente, así que este gráfico " +
                        "(chart %I64d) arranca en MODO OBSERVADOR y reintentará en ~%d s.",
                        APP_NAME, other_uid, g_instance_uid,
                        INSTANCE_LOCK_RETRY_MS / 1000);
            return false;
         }
      }

      g_is_primary_instance   = true;
      g_lock_owner_verified   = true;
      g_next_lock_retry_ms    = 0; // primaria: no necesita reintentos de promoción

      PrintFormat("%s: bloqueo de instancia adquirido (heartbeats validados sin " +
                  "reclamación ajena). Este gráfico es la instancia PRIMARIA.", APP_NAME);
      return true;
   }

   int err = GetLastError();

   if(err == ERR_FILE_ACCESS_DENIED && IsLockFileHeldByLiveInstance())
   {
      g_is_primary_instance = false;
      PrintFormat("%s: otra instancia ya gestiona %s en la cuenta %s (magic %d). " +
                  "Este gráfico arranca en MODO OBSERVADOR.",
                  APP_NAME, _Symbol, AccountLoginToken(), InpMagicNumber);
      return false;
   }

   g_is_primary_instance = InpForcePrimaryOnLockFailure;

   PrintFormat("%s: no se pudo verificar el bloqueo de instancia (error %d%s). Modo: %s.",
               APP_NAME, err,
               (err == ERR_FILE_ACCESS_DENIED)
                  ? "; no se detectó heartbeat reciente, se trata como fallo transitorio del " +
                    "sistema de archivos, no como \"otra instancia\""
                  : "",
               g_is_primary_instance ? "PRIMARIA forzada por input" : "OBSERVADOR (seguro)");

   return g_is_primary_instance;
}

void RetryInstanceLockIfObserver()
{
   if(g_is_primary_instance) return;
   if(IsTesterContext())     return;

   g_lock_attempts++;

   // C1: el primer reintento (a los ~45 s) es conservador: solo promueve si el
   // heartbeat está AUSENTE o vencido. Un acceso denegado puede ser transitorio
   // mientras otra instancia aún es primaria; promover entonces crearía dos
   // primarias simultáneas durante hasta un ciclo de heartbeat (~30 s).
   // A partir del segundo reintento se confía en la exclusividad del sistema de
   // archivos (una primaria sana mantiene el handle abierto todo el tiempo).
   if(InpStrictInstanceLock && g_lock_attempts == 1 && IsLockFileHeldByLiveInstance())
   {
      PrintFormat("%s: reintento de bloqueo pospuesto — sigue habiendo un heartbeat vivo " +
                  "en %s; se espera al siguiente ciclo.", APP_NAME, LockFileName());
      return;
   }

   ResetLastError();

   int handle = FileOpen(LockFileName(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle == INVALID_HANDLE) return;

   // Revalidación anti-doble-primaria (igual que en la adquisición inicial):
   // si otro gráfico escribió un heartbeat fresco y COMPLETO, se cede el
   // handle. La validación exige la marca "written" (ver ParseValidatedLockRecord),
   // de modo que una lectura parcial de una escritura concurrente nunca frena
   // una promoción legítima ni la permite sobre un heartbeat ajeno vigente.
   g_lock_file_handle = handle;
   g_instance_uid     = (long)ChartID();
   WriteInstanceHeartbeat();

   string uid_text, hb_text, written_text;
   if(ReadLockFileFields(uid_text, hb_text, written_text))
   {
      long     other_uid;
      datetime other_hb;
      bool valid_other = ParseValidatedLockRecord(uid_text, hb_text, written_text,
                                                  other_uid, other_hb);

      if(valid_other && other_uid != g_instance_uid &&
         (TimeCurrent() - other_hb) <= INSTANCE_HB_STALE_SEC)
      {
         FileClose(g_lock_file_handle);
         g_lock_file_handle    = INVALID_HANDLE;
         g_lock_owner_verified = false;

         PrintFormat("%s: promoción descartada — el chart %I64d escribió un heartbeat " +
                     "vigente; esta instancia permanece como OBSERVADOR.",
                     APP_NAME, other_uid);
         return;
      }
   }

   g_is_primary_instance = true;
   g_lock_owner_verified = true;
   g_lock_attempts       = 0;
   g_next_lock_retry_ms  = 0; // primaria: no necesita más reintentos de promoción

   PrintFormat("%s: PROMOCIÓN a instancia PRIMARIA — el bloqueo %s quedó libre y este gráfico " +
               "lo ha adquirido (revalidado sin heartbeat ajeno). Se reanuda la gestión automática.",
               APP_NAME, LockFileName());
   SetPanelStatus("Promovido a instancia PRIMARIA: se reanuda la gestión automática.", false);

   ApplyAccountModePolicy();
   RecomputeManagementFlags();
   MarkPanelDirty();
}

void ReleaseInstanceLock()
{
   if(g_lock_file_handle == INVALID_HANDLE) return;

   FileClose(g_lock_file_handle);
   g_lock_file_handle = INVALID_HANDLE;

   if(!IsTesterContext())
      FileDelete(LockFileName(), FILE_COMMON);
}

// C1: verificación periódica de propiedad del lock por la instancia primaria.
// Con dos instancias primarias (adquisición casi simultánea), la que observe
// un heartbeat ajeno más reciente degrada a observadora; si ambas se ven, la
// de uid menor conserva el rol (criterio determinista anti-bloqueo mutuo).
void VerifyLockOwnership()
{
   if(!g_is_primary_instance || IsTesterContext()) return;
   if(g_lock_file_handle == INVALID_HANDLE)         return;

   string uid_text, hb_text, written_text;
   if(!ReadLockFileFields(uid_text, hb_text, written_text)) return;

   long     other_uid;
   datetime other_hb;
   if(!ParseValidatedLockRecord(uid_text, hb_text, written_text, other_uid, other_hb))
      return;

   if(other_uid == 0 || other_uid == g_instance_uid) return;

   bool other_fresh = (TimeCurrent() - other_hb) <= INSTANCE_HB_STALE_SEC;
   if(!other_fresh) return;

   if(other_uid > g_instance_uid)
   {
      PrintFormat("%s: AVISO — el heartbeat del chart %I64d en %s es más reciente que el de " +
                  "esta instancia (%I64d); esa instancia degradará a observadora en su próxima " +
                  "verificación. Esta mantiene el rol PRIMARIO.",
                  APP_NAME, other_uid, LockFileName(), g_instance_uid);
      return;
   }

   FileClose(g_lock_file_handle);
   g_lock_file_handle      = INVALID_HANDLE;
   g_is_primary_instance   = false;
   g_lock_owner_verified   = false;
   g_lock_attempts         = 0;
   g_next_lock_retry_ms    = NowMs() + (ulong)INSTANCE_LOCK_RETRY_MS;

   PrintFormat("%s: DEGRADACIÓN a OBSERVADOR — otra instancia (chart %I64d) adquirió el " +
               "bloqueo %s. Esta instancia deja de ejecutar y gestionar automáticamente.",
               APP_NAME, other_uid, LockFileName());
   SetPanelStatus("Otra instancia tomó el control; este gráfico pasa a modo observador.", true);

   ApplyAccountModePolicy();
   RecomputeManagementFlags();
   MarkPanelDirty();
}

void WriteInstanceHeartbeat()
{
   if(g_lock_file_handle == INVALID_HANDLE) return;

   FileSeek(g_lock_file_handle, 0, SEEK_SET);

   // "written" es deliberadamente lo ÚLTIMO que se escribe: quien lea el
   // archivo mientras esta escritura está en curso verá un heartbeat nuevo sin
   // marca "written" (o con una distinta) y descartará el registro como
   // incompleto (ver ParseValidatedLockRecord). Es la salvaguarda de integridad
   // de lectura del protocolo anti doble-primaria.
   string stamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

   string content = LOCK_HEADER_V1 + "\n" +
                    StringFormat("uid=%I64d\nchart=%I64d\nsymbol=%s\nmagic=%d\nheartbeat=%s\nwritten=%s\n",
                                 g_instance_uid, ChartID(), _Symbol, InpMagicNumber,
                                 stamp, stamp);

   static int s_max_written_len = 0;
   int content_len = StringLen(content);

   if(content_len < s_max_written_len)
   {
      string padding = "";
      for(int i = 0; i < s_max_written_len - content_len; i++) padding += " ";
      content += padding;
   }
   else
   {
      s_max_written_len = content_len;
   }

   FileWriteString(g_lock_file_handle, content);
   FileFlush(g_lock_file_handle);
}

//+------------------------------------------------------------------+
//| GRÁFICO - AJUSTES DEL TERMINAL Y PLANTILLA                       |
//+------------------------------------------------------------------+
void SaveChartSettings()
{
   if(g_chart_settings_saved) return;

   g_saved_show_trade_lvls  = ChartGetInteger(0, CHART_SHOW_TRADE_LEVELS);
   g_saved_drag_trade_lvls  = ChartGetInteger(0, CHART_DRAG_TRADE_LEVELS);
   g_saved_event_mouse_move = ChartGetInteger(0, CHART_EVENT_MOUSE_MOVE);

   g_chart_settings_saved = true;
}

void RestoreChartSettings()
{
   if(!g_chart_settings_saved) return;

   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, g_saved_show_trade_lvls);
   ChartSetInteger(0, CHART_DRAG_TRADE_LEVELS, g_saved_drag_trade_lvls);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE,  g_saved_event_mouse_move);

   g_chart_settings_saved = false;
}

void HideNativeTradeLevels()
{
   if(!InpHideNativeTradeLevels) return;

   if(ChartGetInteger(0, CHART_SHOW_TRADE_LEVELS) != 0)
      ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);

   if(ChartGetInteger(0, CHART_DRAG_TRADE_LEVELS) != 0)
      ChartSetInteger(0, CHART_DRAG_TRADE_LEVELS, false);
}

void ApplyAutoTemplate()
{
   if(!InpEnableAutoTemplate || IsTesterContext()) return;
   if(g_auto_template_failures >= MAX_AUTO_TEMPLATE_FAILURES) return;

   g_auto_template_name = APP_NAME + "_" + SanitizeFileToken(_Symbol);

   if(!ChartSaveTemplate(0, g_auto_template_name))
   {
      g_auto_template_failures++;
      PrintFormat("%s: no se pudo guardar la plantilla automática (error %d).",
                  APP_NAME, GetLastError());
   }
}

//+------------------------------------------------------------------+
//| INDICADORES                                                      |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
{
   if(g_atr_handle_trailing != INVALID_HANDLE)
   {
      IndicatorRelease(g_atr_handle_trailing);
      g_atr_handle_trailing = INVALID_HANDLE;
   }
}

bool EnsureTrailingATRHandle()
{
   if(g_atr_handle_trailing != INVALID_HANDLE) return true;
   if(g_trail_atr_failed) return false;

   g_atr_handle_trailing = iATR(_Symbol, g_trail_atr_tf,
                                (int)MathMax(1, g_trailing_atr_period));

   if(g_atr_handle_trailing == INVALID_HANDLE)
   {
      g_trail_atr_failed = true;
      PrintFormat("%s: no se pudo crear el ATR de trailing (error %d); se usará trailing fijo.",
                  APP_NAME, GetLastError());
      return false;
   }

   return true;
}

bool GetTrailingATR(double &atr_value)
{
   atr_value = 0.0;

   if(!EnsureTrailingATRHandle()) return false;
   if(g_atr_handle_trailing == INVALID_HANDLE)
   {
      PrintFormat("%s: ERROR - Handle de ATR inválido en GetTrailingATR", APP_NAME);
      return false;
   }

   double buffer[];
   ArraySetAsSeries(buffer, true);

   int copied = CopyBuffer(g_atr_handle_trailing, 0, 0, 2, buffer);
   if(copied < 2)
   {
      PrintFormat("%s: ERROR - CopyBuffer de ATR retornó %d elementos (esperado 2)",
                  APP_NAME, copied);
      return false;
   }

   if(buffer[1] <= 0.0 && buffer[0] <= 0.0) return false;

   atr_value = (buffer[1] > 0.0) ? buffer[1] : buffer[0];
   return (atr_value > 0.0);
}

//+------------------------------------------------------------------+
//| ÓRDENES - MODIFICACIÓN Y CANCELACIÓN                             |
//+------------------------------------------------------------------+
bool ModifyPositionLevels(ulong ticket, double sl, double tp, string context)
{
   if(!g_is_primary_instance) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   if(!PositionBelongsToEA(ticket))    return false;

   double norm_sl = (sl > 0.0) ? NormalizeToTick(sl) : 0.0;
   double norm_tp = (tp > 0.0) ? NormalizeToTick(tp) : 0.0;

   double live_sl = PositionGetDouble(POSITION_SL);
   double live_tp = PositionGetDouble(POSITION_TP);
   double tol     = GetTickSize(_Symbol) / 2.0;

   if(MathAbs(live_sl - norm_sl) <= tol && MathAbs(live_tp - norm_tp) <= tol)
      return true;

   string frozen_reason;
   if(PositionIsFrozen(ticket, frozen_reason))
   {
      LogExecution(StringFormat("Modificación pospuesta en el ticket %I64u (%s): %s.",
                                ticket, context, frozen_reason), false);
      return false;
   }

   PrepareTradeObjectForClose();

   bool request_ok = g_trade_object.PositionModify(ticket, norm_sl, norm_tp);
   uint retcode = g_trade_object.ResultRetcode();
   if(request_ok && (IsSuccessfulTradeRetcode(retcode) ||
                     retcode == TRADE_RETCODE_NO_CHANGES))
   {
      RecordManagementTradeResult(ticket, true);
      return true;
   }

   LogExecution(StringFormat("El servidor rechazó la modificación del ticket %I64u (%s): %s.",
                             ticket, context, TradeResultText()), true);
   RecordManagementTradeResult(ticket, false);
   return false;
}

bool CancelAllPendingOrders(string context)
{
   bool all_ok = true;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;

      if(!CancelPendingOrder(ticket, context)) all_ok = false;
   }

   if(all_ok) SetPanelStatus("Órdenes pendientes del EA canceladas.", false);
   else       SetPanelStatus("Algunas órdenes pendientes no pudieron cancelarse.", true);

   return all_ok;
}

//+------------------------------------------------------------------+
//| ÓRDENES - CIERRE DE VOLUMEN                                      |
//+------------------------------------------------------------------+
bool ClosePositionVolume(ulong ticket, double volume_to_close, string context)
{
   if(!g_is_primary_instance) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   if(!PositionBelongsToEA(ticket))
   {
      LogExecution(StringFormat("El ticket %I64u no pertenece a este EA; no se cierra (%s).",
                                ticket, context), true);
      return false;
   }

   double live_volume = PositionGetDouble(POSITION_VOLUME);
   if(live_volume <= 0.0) return false;

   string frozen_reason;
   if(PositionIsFrozen(ticket, frozen_reason))
   {
      LogExecution(StringFormat("Cierre pospuesto en el ticket %I64u (%s): %s.",
                                ticket, context, frozen_reason), false);
      return false;
   }

   bool   below_min;
   double target = NormalizeVolume(_Symbol, MathMin(volume_to_close, live_volume), below_min);

   double min_vol   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double remainder = live_volume - target;

   if(below_min || target <= 0.0)
   {
      LogExecution(StringFormat("El tramo a cerrar (%s lotes) queda por debajo del mínimo; " +
                                "se cierra la posición completa del ticket %I64u (%s).",
                                DoubleToString(volume_to_close, 4), ticket, context), false);
      target    = live_volume;
      remainder = 0.0;
   }
   else if(remainder > 0.0 && remainder < min_vol - 1e-9)
   {
      LogExecution(StringFormat("El resto tras el parcial (%s lotes) sería inferior al mínimo; " +
                                "se cierra el total del ticket %I64u (%s).",
                                DoubleToString(remainder, 4), ticket, context), false);
      target = live_volume;
   }

   PrepareTradeObjectForClose();

   bool request_ok = (target >= live_volume - 1e-9)
                     ? g_trade_object.PositionClose(ticket)
                     : g_trade_object.PositionClosePartial(ticket, target);
   bool ok = request_ok && IsSuccessfulTradeRetcode(g_trade_object.ResultRetcode());

   if(!ok)
   {
      LogExecution(StringFormat("Cierre rechazado en el ticket %I64u (%s): %s.",
                                ticket, context, TradeResultText()), true);
      RecordManagementTradeResult(ticket, false);
      return false;
   }

   RecordManagementTradeResult(ticket, true);

   LogExecution(StringFormat("Cerrados %s lotes del ticket %I64u (%s).",
                             DoubleToString(target, VolumeDecimalsFromStep(_Symbol)),
                             ticket, context), false);

   MarkStateDirty();
   MarkPanelDirty();

   return true;
}

bool CloseZoneVolume(int idx, double percent, string context)
{
   if(idx < 0 || idx >= ArraySize(g_positions)) return false;

   if(percent <= 0.0)
   {
      SetPanelStatus("Porcentaje de cierre inválido (debe ser mayor que 0).", true);
      return false;
   }

   if(!g_positions[idx].is_executed || g_positions[idx].ticket == 0 ||
      !PositionSelectByTicket(g_positions[idx].ticket))
   {
      if(ZoneHasLivePendingOrder(idx))
         return CancelPendingOrder(g_positions[idx].order_ticket, context);

      SetPanelStatus("Esta posición no tiene operación viva en mercado.", true);
      return false;
   }

   double live_volume = PositionGetDouble(POSITION_VOLUME);
   double fraction    = MathMin(100.0, percent) / 100.0;

   bool ok = ClosePositionVolume(g_positions[idx].ticket, live_volume * fraction, context);

   if(ok)
   {
      g_positions[idx].qty_valid = false;

      if(!PositionSelectByTicket(g_positions[idx].ticket))
         MarkZoneClosed(idx);
      else
         UpdatePositionObjects(idx);
   }

   return ok;
}

//+------------------------------------------------------------------+
//| ÓRDENES - PLAN, ENVÍO Y REINTENTOS                               |
//+------------------------------------------------------------------+
bool IsRetryableRetcode(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_LOCKED:
         return true;
   }
   return false;
}

// M-1: encolar una cancelación pendiente de reintento. Se usa cuando el
// servidor rechaza el borrado con un retcode recuperable: en lugar de dormir
// el hilo del EA (Sleep bloquea OnTick/OnTimer y retrasa trailing/BE de otras
// posiciones), la orden queda encolada y ProcessPendingCancels() la reintenta
// desde OnTick/OnTimer cuando llega su momento.
void QueuePendingCancel(ulong order_ticket, int attempt, ulong delay_ms, string context)
{
   if(order_ticket == 0) return;

   for(int i = 0; i < ArraySize(g_pending_cancels); i++)
   {
      if(g_pending_cancels[i].order_ticket == order_ticket)
      {
         g_pending_cancels[i].attempt       = attempt;
         g_pending_cancels[i].next_retry_ms = NowMs() + delay_ms;
         g_pending_cancels[i].context       = context;
         return;
      }
   }

   int n = ArraySize(g_pending_cancels);
   ArrayResize(g_pending_cancels, n + 1);

   g_pending_cancels[n].order_ticket  = order_ticket;
   g_pending_cancels[n].attempt       = attempt;
   g_pending_cancels[n].next_retry_ms = NowMs() + delay_ms;
   g_pending_cancels[n].context       = context;
}

void RemovePendingCancelAt(int idx)
{
   int total = ArraySize(g_pending_cancels);
   if(idx < 0 || idx >= total) return;

   for(int i = idx; i < total - 1; i++)
      g_pending_cancels[i] = g_pending_cancels[i + 1];

   ArrayResize(g_pending_cancels, total - 1);
}

bool CancelPendingOrder(ulong order_ticket, string context)
{
   if(order_ticket == 0) return false;

   // Si ya hay una cancelación encolada para esta orden, no se duplica el
   // esfuerzo: se devuelve "no completada" y la cola seguirá reintentando.
   for(int q = 0; q < ArraySize(g_pending_cancels); q++)
      if(g_pending_cancels[q].order_ticket == order_ticket) return false;

   if(!OrderSelect(order_ticket))
   {
      // Ya no existe en el libro: o se canceló antes o fue ejecutada.
      // La reconciliación vía OnTradeTransaction determinará el caso.
      FinishPendingCancel(order_ticket, true, context);
      return true;
   }

   bool request_ok = g_trade_object.OrderDelete(order_ticket);
   uint retcode    = g_trade_object.ResultRetcode();

   if(request_ok && IsSuccessfulTradeRetcode(retcode))
   {
      FinishPendingCancel(order_ticket, true, context);
      return true;
   }

   // El borrado puede tardar en propagarse aunque la petición haya sido
   // aceptada: si la orden ya no está en el libro, se da por cancelada.
   if(!OrderSelect(order_ticket))
   {
      FinishPendingCancel(order_ticket, true, context);
      return true;
   }

   if(!IsRetryableRetcode(retcode))
   {
      LogExecution(StringFormat("No se pudo cancelar la orden %I64u (%s): %s.",
                                order_ticket, context, TradeResultText()), true);
      FinishPendingCancel(order_ticket, false, context);
      return false;
   }

   // Retry diferido SIN Sleep(): primer reintento inmediato al siguiente
   // tick/timer y los posteriores con backoff creciente (máx. 5 s). El intento
   // nº 1 se ha consumido aquí, por lo que el primero de la cola es el nº 2.
   int next_attempt = 2;
   ulong delay_ms   = (ulong)MathMax(250, MathMin(5000, g_backoff_base * next_attempt));

   QueuePendingCancel(order_ticket, next_attempt, delay_ms, context);

   LogExecution(StringFormat("La cancelación de la orden %I64u quedó encolada (%s): %s. " +
                             "Se reintentará sin bloquear la gestión.",
                             order_ticket, context, TradeResultText()), false);

   return false;
}

// Finaliza la cancelación de una orden: limpia estado local, zona asociada y
// pendings de ejecución. `success` indica si la orden quedó efectivamente
// fuera del libro.
void FinishPendingCancel(ulong order_ticket, bool success, string context)
{
   for(int q = ArraySize(g_pending_cancels) - 1; q >= 0; q--)
      if(g_pending_cancels[q].order_ticket == order_ticket)
         RemovePendingCancelAt(q);

   if(!success) return;

   LogExecution(StringFormat("Orden pendiente %I64u cancelada (%s).",
                             order_ticket, context), false);

   int idx = FindPositionByOrderTicket(order_ticket);
   if(idx >= 0)
   {
      g_positions[idx].order_ticket = 0;
      g_positions[idx].is_locked    = false;
      UpdatePositionObjects(idx);
   }

   if(g_pending_fill_order == order_ticket)
   {
      g_pending_fill_order   = 0;
      g_pending_fill_zone_id = -1;
      g_pending_fill_ms      = 0;
   }

   MarkStateDirty();
   MarkPanelDirty();
}

// Reintentos diferidos de cancelación — se llama desde OnTick y OnTimer.
// Recorrido ASCENDENTE con re-scaneo explícito: FinishPendingCancel puede
// retirar elementos en cualquier posición (acorta el array y desplaza los
// índices), por lo que no es seguro asumir que el índice local sigue vigente.
void ProcessPendingCancels()
{
   if(ArraySize(g_pending_cancels) == 0) return;
   if(IsStopped()) return;

   ulong now = NowMs();

   for(int i = 0; i < ArraySize(g_pending_cancels); i++)
   {
      ulong  ticket   = g_pending_cancels[i].order_ticket;
      int    attempt  = g_pending_cancels[i].attempt;
      ulong  retry_at = g_pending_cancels[i].next_retry_ms;
      string ctx      = g_pending_cancels[i].context;

      if(now < retry_at) continue;

      if(!OrderSelect(ticket))
      {
         FinishPendingCancel(ticket, true, ctx);
         i = -1; // cola posiblemente acortada/desplazada: reiniciar barrido
         continue;
      }

      bool request_ok = g_trade_object.OrderDelete(ticket);
      uint retcode    = g_trade_object.ResultRetcode();

      bool deleted_now = request_ok && IsSuccessfulTradeRetcode(retcode);

      if(!deleted_now && !OrderSelect(ticket))
         deleted_now = true; // propagación completada entre bastidores

      if(deleted_now)
      {
         FinishPendingCancel(ticket, true, ctx);
         i = -1;
         continue;
      }

      if(!IsRetryableRetcode(retcode) || attempt >= CANCEL_MAX_ATTEMPTS)
      {
         LogExecution(StringFormat("La orden pendiente %I64u sigue activa tras %d intentos " +
                                   "de cancelación (%s): %s. Intervenga manualmente.",
                                   ticket, attempt, ctx, TradeResultText()), true);
         FinishPendingCancel(ticket, false, ctx);
         i = -1;
         continue;
      }

      attempt++;
      ulong delay_ms = (ulong)MathMax(250, MathMin(5000, g_backoff_base * attempt));

      // Localizar de nuevo (los índices pueden haber cambiado al retirar otros).
      for(int j = 0; j < ArraySize(g_pending_cancels); j++)
      {
         if(g_pending_cancels[j].order_ticket == ticket)
         {
            g_pending_cancels[j].attempt       = attempt;
            g_pending_cancels[j].next_retry_ms = now + delay_ms;
            break;
         }
      }

      // Este elemento ya fue procesado en esta pasada; avanzar sin re-barrer
      // (no se retiró ningún elemento, así que los índices siguen vigentes).
   }
}

// C2: retcodes "ambiguos" — el servidor PUDO haber ejecutado la orden aunque no
// lo confirme. Tras uno de ellos NUNCA se reenvía sin reconciliar con éxito.
bool IsAmbiguousSendRetcode(uint retcode)
{
   return (retcode == TRADE_RETCODE_TIMEOUT || retcode == TRADE_RETCODE_CONNECTION);
}

bool IsSuccessfulTradeRetcode(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE:
      case TRADE_RETCODE_DONE_PARTIAL:
      case TRADE_RETCODE_PLACED:
         return true;
   }

   return false;
}

// Búsqueda genérica de una posición propia (magic+símbolo) creada desde
// `not_before` cuyo comentario coincida con `comment`. Núcleo único de la
// reconciliación de envíos (antes duplicado en dos bucles idénticos).
bool FindOwnPositionByComment(datetime not_before, string comment,
                              ulong &out_ticket, double &out_volume)
{
   out_ticket = 0;
   out_volume = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetString(POSITION_COMMENT) != comment) continue;
      if((datetime)PositionGetInteger(POSITION_TIME) < not_before) continue;

      out_ticket = ticket;
      out_volume = PositionGetDouble(POSITION_VOLUME);
      return true;
   }

   return false;
}

// Intento de reconciliación puntual: busca en la cuenta una orden pendiente o
// posición que este plan haya podido crear sin confirmación. Única fuente de
// verdad para los tres escenarios de ProcessOrderPlan (post-envío, sonda
// programada y reconciliación tardía en el timeout global).
bool TryReconcilePlanSend(ulong &out_order_ticket, ulong &out_position_ticket, double &out_filled)
{
   out_order_ticket    = 0;
   out_position_ticket = 0;
   out_filled          = 0.0;

   if(g_plan.comment == "" || g_order_attempt_time <= 0) return false;

   datetime not_before = g_order_attempt_time - 2;

   if(g_plan.is_pending)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket)) continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetString(ORDER_COMMENT) != g_plan.comment) continue;
         if((datetime)OrderGetInteger(ORDER_TIME_SETUP) < not_before) continue;

         out_order_ticket = ticket;
         return true;
      }

      // La pendiente ya no está en el libro: pudo haberse rellenado mientras
      // el envío daba timeout. Se comprueba también la posición resultante.
      if(FindOwnPositionByComment(not_before, g_plan.comment,
                                  out_position_ticket, out_filled))
      {
         out_order_ticket = out_position_ticket; // en pendientes el ticket de
         return true;                            // posición vale como orden-fill
      }

      return false;
   }

   return FindOwnPositionByComment(not_before, g_plan.comment,
                                   out_position_ticket, out_filled);
}

bool ReconcilePendingPlanSend(ulong &out_order_ticket, ulong &out_position_ticket, double &out_filled)
{
   return TryReconcilePlanSend(out_order_ticket, out_position_ticket, out_filled);
}

void RecordManagementTradeResult(ulong ticket, bool success)
{
   int m = FindManagementIndex(ticket);
   if(m < 0) return;

   if(success)
   {
      g_management[m].fail_count       = 0;
      g_management[m].failure_reported = false;
      return;
   }

   g_management[m].fail_count++;
}

void ResetOrderPlan()
{
   g_plan.active        = false;
   g_plan.is_pending    = false;
   g_plan.type          = ORDER_TYPE_BUY;
   g_plan.volume        = 0.0;
   g_plan.price         = 0.0;
   g_plan.sl            = 0.0;
   g_plan.tp            = 0.0;
   g_plan.comment       = "";
   g_plan.zone_id       = -1;
   g_plan.expiration    = 0;

   g_order_retry_active = false;
   g_order_retry_count  = 0;
   g_order_retry_time   = 0;
   g_order_lock_time    = 0;
   g_order_attempt_time = 0;

   // El estado de ambigüedad pertenece al envío en curso: nunca debe sobrevivir
   // a un reset/aborto del plan (evita que el siguiente arranque con sondas
   // agotadas y se auto-abandone sin intentos reales).
   g_send_uncertain   = false;
   g_uncertain_probes = 0;
}

void AbortOrderPlan(string reason, bool problem)
{
   long zone_id = g_plan.zone_id;

   ResetOrderPlan();

   int idx = FindPositionById(zone_id);
   if(idx >= 0)
   {
      g_positions[idx].is_locked = false;
      UpdatePositionObjects(idx);
   }

   SetPanelStatus(reason, problem);
   MarkPanelDirty();
}

string BuildOrderComment(long zone_id)
{
   string comment = APP_NAME + "#" + IntegerToString(zone_id);

   if(StringLen(comment) > ORDER_COMMENT_MAX_LEN)
      comment = StringSubstr(comment, 0, ORDER_COMMENT_MAX_LEN);

   return comment;
}

ulong ResolvePositionFromOrder(ulong order_ticket, ENUM_ORDER_TYPE sent_type, double sent_volume,
                               double sent_price, datetime sent_attempt)
{
   if(order_ticket > 0)
   {
      if(HistoryOrderSelect(order_ticket))
      {
         datetime order_time = (datetime)HistoryOrderGetInteger(order_ticket, ORDER_TIME_SETUP);
         HistorySelect(order_time - 60, TimeCurrent() + 60);

         int deals = HistoryDealsTotal();
         for(int i = 0; i < deals; i++)
         {
            ulong deal = HistoryDealGetTicket(i);
            if(deal == 0) continue;
            if((ulong)HistoryDealGetInteger(deal, DEAL_ORDER) != order_ticket) continue;

            ulong pos_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
            if(pos_id > 0 && PositionSelectByTicket(pos_id)) return pos_id;
         }
      }
   }

   long   sent_position_type = (sent_type == ORDER_TYPE_SELL) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   double price_tolerance    = 100 * SymbolPointSafe(_Symbol);

   ulong best_ticket    = 0;
   long  best_time_diff = -1;

   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0) continue;
      if(!PositionBelongsToEA(ticket)) continue;
      if(FindPositionByPositionTicket(ticket) >= 0) continue;

      if(sent_volume > 0.0 &&
         MathAbs(PositionGetDouble(POSITION_VOLUME) - sent_volume) > 1e-8) continue;

      if((long)PositionGetInteger(POSITION_TYPE) != sent_position_type) continue;

      datetime pos_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(sent_attempt > 0 && pos_time < sent_attempt - 5) continue;

      if(sent_price > 0.0)
      {
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         if(MathAbs(open_price - sent_price) > price_tolerance) continue;
      }

      long time_diff = (long)MathAbs((long)pos_time - (long)sent_attempt);
      if(best_ticket == 0 || time_diff < best_time_diff)
      {
         best_ticket    = ticket;
         best_time_diff = time_diff;
      }
   }

   return best_ticket;
}

void ExecuteSelectedOrder()
{
   if(g_order_retry_active)
   {
      SetPanelStatus("Ya hay un envío de orden en curso; espere a que termine.", true);
      return;
   }

   if(!g_exec_allowed)
   {
      SetPanelStatus("Ejecución desactivada: " +
                     (g_degraded_reason == "" ? "revise los permisos del terminal"
                                              : g_degraded_reason) + ".", true);
      return;
   }

   if(g_is_limit_locked)
   {
      SetPanelStatus("Límite de cuenta activo: " + g_limit_lock_reason, true);
      return;
   }

   // C3/#5: límite de posiciones simultáneas del EA (magic propio).
   // 0 = sin límite. Se cuentan solo posiciones abiertas reales del EA en
   // este símbolo, no los borradores visuales.
   if(InpMaxOpenPositions > 0)
   {
      int ea_open_count = 0;
      for(int c = PositionsTotal() - 1; c >= 0; c--)
      {
         ulong t = PositionGetTicket(c);
         if(t == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         ea_open_count++;
      }
      if(ea_open_count >= InpMaxOpenPositions)
      {
         SetPanelStatus(StringFormat("Límite de posiciones alcanzado (%d/%d). Suba el límite o cierre alguna.",
                                     ea_open_count, InpMaxOpenPositions), true);
         LogExecution(StringFormat("Ejecución bloqueada: %d posiciones abiertas del EA >= InpMaxOpenPositions (%d).",
                                   ea_open_count, InpMaxOpenPositions), true);
         return;
      }
   }

   int idx = GetTargetPositionIndex();
   if(idx < 0)
   {
      SetPanelStatus("Seleccione una posición antes de ejecutar.", true);
      return;
   }

   SVisualPosition pos = g_positions[idx];

   if(pos.is_closed)
   {
      SetPanelStatus("La posición está cerrada; cree una nueva.", true);
      return;
   }

   if(pos.is_executed || pos.order_ticket > 0)
   {
      SetPanelStatus("La posición ya tiene una orden viva.", true);
      return;
   }

   string zone_error;
   if(!ValidateZone(pos, zone_error))
   {
      SetPanelStatus("Posición inválida: " + zone_error + ".", true);
      return;
   }

   MqlTick tick;
   string  quote_reason;
   if(!GetTradableTick(_Symbol, tick, quote_reason))
   {
      SetPanelStatus("No se puede ejecutar: " + quote_reason + ".", true);
      return;
   }

   bool   is_long   = (pos.type == PLANNER_POS_BUY);
   double market    = is_long ? tick.ask : tick.bid;
   double tick_size = GetTickSize(_Symbol);

   if(tick_size <= 0.0)
   {
      SetPanelStatus("El símbolo no reporta un tamaño de tick válido.", true);
      return;
   }

   double distance_ticks = MathAbs(pos.entry_price - market) / tick_size;

   bool            use_market   = false;
   ENUM_ORDER_TYPE pending_type = ORDER_TYPE_BUY_LIMIT;

   if(InpExecMode == EXEC_MARKET_ONLY || distance_ticks <= g_entry_tolerance_ticks)
   {
      use_market = true;
   }
   else if(InpExecMode == EXEC_PENDING)
   {
      if(is_long)
         pending_type = (pos.entry_price < tick.ask) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
      else
         pending_type = (pos.entry_price > tick.bid) ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;

      if(!SymbolAllowsPendingType(_Symbol, pending_type))
      {
         SetPanelStatus("El bróker no admite ese tipo de orden pendiente en " + _Symbol + ".",
                        true);
         return;
      }
   }
   else
   {
      SetPanelStatus(StringFormat("Modo estricto: la entrada está a %.1f ticks del mercado " +
                                  "(tolerancia %.1f). Acerque la posición o cambie InpExecMode.",
                                  distance_ticks, g_entry_tolerance_ticks), true);
      return;
   }

   double entry_reference = use_market ? market : pos.entry_price;
   double close_reference = use_market ? (is_long ? tick.bid : tick.ask) : pos.entry_price;

   bool   below_min;
   string volume_reason;
   double volume = CalculateVolumeEx(_Symbol, pos.type, entry_reference, pos.sl_price,
                                     below_min, volume_reason);

   if(volume <= 0.0)
   {
      SetPanelStatus("No se puede ejecutar: " + volume_reason, true);
      return;
   }

   string distance_reason;
   if(!ValidateStopDistance(_Symbol, pos.type, entry_reference, close_reference,
                            pos.sl_price, pos.tp_price, distance_reason))
   {
      SetPanelStatus("Niveles no válidos: " + distance_reason + ".", true);
      return;
   }

   g_plan.active        = true;
   g_plan.is_pending    = !use_market;
   g_plan.type          = use_market ? (is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL)
                                     : pending_type;
   g_plan.volume        = volume;
   g_plan.price         = use_market ? market : NormalizeToTick(pos.entry_price);
   g_plan.sl            = NormalizeToTick(pos.sl_price);
   g_plan.tp            = NormalizeToTick(pos.tp_price);
   g_plan.comment       = BuildOrderComment(pos.id);
   g_plan.zone_id       = pos.id;
   g_plan.expiration    = 0;

   if(!use_market && InpPendingExpiryMinutes > 0)
      g_plan.expiration = TimeCurrent() + (datetime)(InpPendingExpiryMinutes * 60);

   g_order_retry_active = true;
   g_order_retry_count  = 0;
   g_order_retry_time   = 0;
   g_order_lock_time    = NowMs();
   g_order_attempt_time = TimeCurrent();

   // El contador de sondas es por-intento: un plan nuevo no hereda el desgaste
   // de ambigüedades de envíos anteriores.
   g_send_uncertain   = false;
   g_uncertain_probes = 0;

   g_positions[idx].is_locked = true;
   UpdatePositionObjects(idx);

   SetPanelStatus(StringFormat("Enviando %s de %s lotes...",
                               OrderTypeText(g_plan.type),
                               DoubleToString(volume, VolumeDecimalsFromStep(_Symbol))), false);

   ProcessOrderPlan();
}

void ProcessOrderPlan()
{
   if(!g_plan.active || !g_order_retry_active) return;

   ulong now = NowMs();

   if(now - g_order_lock_time > (ulong)ORDER_LOCK_TIMEOUT)
   {
      // C2: si el envío quedó ambiguo, no se abandona sin más: antes de nada se
      // hace una última reconciliación. Si la posición/orden ya existe en la
      // cuenta, se completa el plan como exitoso en lugar de abortar (evita
      // dejar una operación real "huérfana" del plan y un falso abandono).
      if(g_send_uncertain)
      {
         ulong  recon_order = 0, recon_position = 0;
         double recon_filled = 0.0;

         if(ReconcilePendingPlanSend(recon_order, recon_position, recon_filled))
         {
            LogExecution(StringFormat(
               "Timeout de envío con reconciliación tardía exitosa: la %s ya estaba en la " +
               "cuenta; el plan se completa como enviado.",
               g_plan.is_pending ? "orden pendiente" : "posición"), true);

            g_send_uncertain   = false;
            g_uncertain_probes = 0;

            long  zone_id     = g_plan.zone_id;
            bool  was_pending = g_plan.is_pending;

            int idx = FindPositionById(zone_id);
            ResetOrderPlan();

            if(idx < 0)
            {
               LogExecution("La orden se envió, pero la posición asociada ya no existe; verifique el resultado en su cuenta.",
                            true);
               return;
            }

            if(was_pending && recon_order > 0)
            {
               g_positions[idx].order_ticket = recon_order;
               g_positions[idx].is_locked    = true;

               g_pending_fill_order   = recon_order;
               g_pending_fill_zone_id = zone_id;
               g_pending_fill_ms      = NowMs();

               SetPanelStatus(StringFormat("Orden pendiente %I64u colocada en %s.",
                                           recon_order, DoubleToString(g_positions[idx].entry_price,
                                                                       _Digits)), false);
            }
            else if(!was_pending && recon_position > 0)
            {
               RegisterPositionManagement(recon_position, idx);
               SetPanelStatus(StringFormat("Posición %I64u abierta con %s lotes.",
                                           recon_position,
                                           DoubleToString(recon_filled, VolumeDecimalsFromStep(_Symbol))),
                              false);
            }

            UpdatePositionObjects(idx);
            MarkStateDirty();
            MarkPanelDirty();
            RequestRedraw();
            return;
         }
      }

      AbortOrderPlan("Envío de orden abandonado por tiempo de espera excedido.", true);
      return;
   }

   if(g_order_retry_time > 0 && now < g_order_retry_time) return;

   if(!g_exec_allowed || g_is_limit_locked)
   {
      AbortOrderPlan("Envío cancelado: la ejecución dejó de estar permitida.", true);
      return;
   }

   MqlTick tick;
   string  quote_reason;
   if(!GetTradableTick(_Symbol, tick, quote_reason))
   {
      g_order_retry_count++;
      if(g_order_retry_count > g_max_retries)
      {
         AbortOrderPlan("Envío cancelado: " + quote_reason + ".", true);
         return;
      }

      int shift = (int)MathMin(MAX_BACKOFF_SHIFT, g_order_retry_count);
      g_order_retry_time = now + (ulong)MathMin(MAX_BACKOFF_MS, g_backoff_base << shift);
      return;
   }

   ConfigureTradeObject();

   bool     ok        = false;
   double   requested = g_plan.volume;
   datetime sent_attempt = TimeCurrent(); // timestamp LOCAL de la petición: más
                                          // conservador que el time-of-server y
                                          // compatible con el margen de -2s de
                                          // la reconciliación (evita perder un
                                          // fill cuyo POSITION_TIME se atrase)

   if(!g_plan.is_pending)
   {
      g_plan.price = (g_plan.type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;

      ok = g_trade_object.PositionOpen(_Symbol, g_plan.type, g_plan.volume, g_plan.price,
                                       g_plan.sl, g_plan.tp, g_plan.comment);
   }
   else
   {
      ENUM_ORDER_TYPE_TIME type_time = (g_plan.expiration > 0) ? ORDER_TIME_SPECIFIED
                                                               : ORDER_TIME_GTC;

      ok = g_trade_object.OrderOpen(_Symbol, g_plan.type, g_plan.volume, 0.0, g_plan.price,
                                    g_plan.sl, g_plan.tp, type_time, g_plan.expiration,
                                    g_plan.comment);
   }

   g_order_attempt_time = sent_attempt;

   uint retcode = g_trade_object.ResultRetcode();
   bool server_accepted = ok && IsSuccessfulTradeRetcode(retcode);

   bool missing_confirmation = false;
   if(server_accepted && g_plan.is_pending && g_trade_object.ResultOrder() == 0)
   {
      server_accepted       = false;
      missing_confirmation  = true;
   }

   if(server_accepted && !g_plan.is_pending && g_trade_object.ResultDeal() == 0)
   {
      server_accepted       = false;
      missing_confirmation  = true;
   }

   ulong  result_order_ticket        = server_accepted ? g_trade_object.ResultOrder() : 0;
   double result_filled              = server_accepted ? g_trade_object.ResultVolume() : 0.0;
   ulong  reconciled_position_ticket = 0;

   if(!server_accepted)
   {
      bool should_reconcile = IsRetryableRetcode(retcode) || missing_confirmation;

      ulong  recon_order = 0, recon_position = 0;
      double recon_filled = 0.0;
      bool reconciled = should_reconcile &&
                         ReconcilePendingPlanSend(recon_order, recon_position, recon_filled);

      if(reconciled)
      {
         server_accepted             = true;
         result_order_ticket         = recon_order;
         reconciled_position_ticket  = recon_position;
         result_filled               = recon_filled;

         LogExecution(StringFormat(
            "Reconciliado tras '%s': ya existía la %s en la cuenta; se trata como envío " +
            "exitoso y no se reintenta.",
            TradeResultText(), g_plan.is_pending ? "orden pendiente" : "posición"), false);
      }
      else if(!IsRetryableRetcode(retcode))
      {
         string reject_msg = missing_confirmation
            ? ("El servidor confirmó la orden pero no llegó el ticket/deal de vuelta, y no se " +
               "encontró la operación en la cuenta. Verifíquela manualmente antes de reintentar.")
            : ("El servidor rechazó la orden: " + TradeResultText() + ".");
         AbortOrderPlan(reject_msg, true);
         return;
      }
      else if(g_plan.is_pending)
      {
         // Una orden pendiente NO rellenada puede reenviarse con seguridad: si la
         // primera petición sí llegó, la reconciliación por comment ya la habría
         // encontrado arriba (y un duplicado GTC con distinto precio es imposible).
         g_order_retry_count++;

         if(g_order_retry_count > g_max_retries)
         {
            AbortOrderPlan(StringFormat("Orden abandonada tras %d intentos: %s.",
                                        g_order_retry_count - 1, TradeResultText()), true);
            return;
         }

         int shift = (int)MathMin(MAX_BACKOFF_SHIFT, g_order_retry_count);
         g_order_retry_time = now + (ulong)MathMin(MAX_BACKOFF_MS, g_backoff_base << shift);

         LogExecution(StringFormat("Reintento %d/%d tras %s.",
                                   g_order_retry_count, g_max_retries, TradeResultText()), false);
         return;
      }
      else
      {
         // C2 — ENVÍO DE MERCADO AMBIGUO: nunca se reintenta sin reconciliar.
         // Si el retcode sugiere que la petición PUDO llegar al servidor
         // (timeout/conexión), o el resultado llegó inconsistente, se marca el
         // envío como incierto y el primer reintento espera una ventana larga
         // (AMBIGUOUS_SEND_WAIT_MS) para dar tiempo a que la posición aparezca
         // en la cuenta. Además, aunque otro tick active el reintento antes de
         // tiempo, se realizan sondas de reconciliación periódicas; si alguna
         // encuentra la posición, se adopta como envío exitoso. Solo cuando las
         // sondas se agotan SIN encontrar nada se abandona el plan pidiendo
         // verificación manual — jamás se abre una segunda posición a ciegas.
         bool was_uncertain = g_send_uncertain;

         if(IsAmbiguousSendRetcode(retcode) || missing_confirmation || was_uncertain)
            g_send_uncertain = true;

         if(g_send_uncertain)
         {
            if(g_uncertain_probes >= UNCERTAIN_PROBE_MAX)
            {
               AbortOrderPlan("Envío de mercado NO confirmado tras varias comprobaciones: el " +
                              "servidor pudo haberlo ejecutado sin confirmación. NO se reintenta " +
                              "para evitar una posición duplicada. Verifique manualmente su cuenta.",
                              true);
               return;
            }

            int probe_shift = (int)MathMin(3, g_uncertain_probes);
            ulong probe_delay = (ulong)MathMin(UNCERTAIN_PROBE_MAX_DELAY_MS,
                                               (was_uncertain ? UNCERTAIN_PROBE_BASE_MS
                                                              : AMBIGUOUS_SEND_WAIT_MS) << probe_shift);
            g_uncertain_probes++;

            g_order_retry_time = now + probe_delay;
            if(g_order_retry_time - now > (ulong)(ORDER_LOCK_TIMEOUT - 2000))
               g_order_retry_time = g_order_lock_time + (ulong)ORDER_LOCK_TIMEOUT - 2000;

            LogExecution(StringFormat("Envío de mercado ambiguo (%s): NO se reintenta aún; " +
                                      "sonda de reconciliación %d/%d programada en %.1f s. " +
                                      "Si la posición apareció realmente, se reconocerá sola.",
                                      TradeResultText(), g_uncertain_probes, UNCERTAIN_PROBE_MAX,
                                      (double)(g_order_retry_time - now) / 1000.0), true);
            return;
         }

         g_order_retry_count++;

         if(g_order_retry_count > g_max_retries)
         {
            AbortOrderPlan(StringFormat("Orden abandonada tras %d intentos: %s.",
                                        g_order_retry_count - 1, TradeResultText()), true);
            return;
         }

         int shift = (int)MathMin(MAX_BACKOFF_SHIFT, g_order_retry_count);
         g_order_retry_time = now + (ulong)MathMin(MAX_BACKOFF_MS, g_backoff_base << shift);

         LogExecution(StringFormat("Reintento %d/%d tras %s.",
                                   g_order_retry_count, g_max_retries, TradeResultText()), false);
         return;
      }
   }

   // Envío confirmado (directamente o vía reconciliación): el estado ambiguo ya
   // no aplica — la operación existe y este plan la reconoce.
   g_send_uncertain   = false;
   g_uncertain_probes = 0;

   long  zone_id      = g_plan.zone_id;
   bool  was_pending  = g_plan.is_pending;
   ulong order_ticket = result_order_ticket;
   double filled      = result_filled;

   ENUM_ORDER_TYPE sent_type   = g_plan.type;
   double          sent_price  = g_plan.price;
   double          sent_volume = requested;
   // (no re-declarar 'sent_attempt': ya existe en el ámbito de la función)

   if(!was_pending && filled > 0.0 && requested > 0.0)
   {
      double deviation = MathAbs(filled - requested) / requested * 100.0;
      if(deviation > g_max_vol_dev_pct)
         LogExecution(StringFormat("El volumen ejecutado (%s) se desvía %.2f%% del solicitado (%s).",
                                   DoubleToString(filled, 4), deviation,
                                   DoubleToString(requested, 4)), true);
   }

   int idx = FindPositionById(zone_id);
   ResetOrderPlan();

   if(idx < 0)
   {
      LogExecution("La orden se envió, pero la posición asociada ya no existe; verifique el resultado en su cuenta.",
                   true);
      return;
   }

   if(was_pending)
   {
      g_positions[idx].order_ticket = order_ticket;
      g_positions[idx].is_locked    = true;

      g_pending_fill_order   = order_ticket;
      g_pending_fill_zone_id = zone_id;
      g_pending_fill_ms      = NowMs();

      SetPanelStatus(StringFormat("Orden pendiente %I64u colocada en %s.",
                                  order_ticket, DoubleToString(g_positions[idx].entry_price,
                                                               _Digits)), false);
   }
   else
   {
      ulong position_ticket = (reconciled_position_ticket != 0)
                                 ? reconciled_position_ticket
                                 : ResolvePositionFromOrder(order_ticket, sent_type, sent_volume,
                                                            sent_price, sent_attempt);

      if(position_ticket == 0)
      {
         LogExecution("La orden se ejecutó, pero no se pudo localizar el ticket de la posición; " +
                      "se intentará adoptarla automáticamente.", true);
      }
      else
      {
         RegisterPositionManagement(position_ticket, idx);
         SetPanelStatus(StringFormat("Posición %I64u abierta con %s lotes.",
                                     position_ticket,
                                     DoubleToString(filled > 0.0 ? filled : requested,
                                                    VolumeDecimalsFromStep(_Symbol))), false);
      }
   }

   UpdatePositionObjects(idx);
   MarkStateDirty();
   MarkPanelDirty();
   RequestRedraw();
}

//+------------------------------------------------------------------+
//| GESTIÓN AUTOMÁTICA - PARCIALES, BREAK-EVEN Y TRAILING            |
//+------------------------------------------------------------------+
double CurrentRMultiple(int m)
{
   if(!SafeArrayAccess(m, ArraySize(g_management), "CurrentRMultiple"))
      return 0.0;

   if(g_management[m].risk_distance <= 0.0)
      return 0.0;

   if(!PositionSelectByTicket(g_management[m].ticket)) return 0.0;

   MqlTick tick;
   string  reason;
   if(!GetTradableTick(_Symbol, tick, reason)) return 0.0;

   bool   is_long = (g_management[m].order_type == POSITION_TYPE_BUY);
   double price   = is_long ? tick.bid : tick.ask;
   double move    = is_long ? (price - g_management[m].entry_price)
                            : (g_management[m].entry_price - price);

   return move / g_management[m].risk_distance;
}

void ApplyPartials(int m)
{
   if(!IsManagementValid(m)) return;
   if(!g_management[m].plan_partials_on) return;
   if(!PositionSelectByTicket(g_management[m].ticket)) return;

   for(int s = 0; s < PARTIAL_STAGES; s++)
   {
      if(!g_management[m].plan_stage_active[s]) continue;
      if(g_management[m].partial_resolved[s])   continue;
      if(!PartialStageReached(m, s))             continue;

      double live_volume = PositionGetDouble(POSITION_VOLUME);
      if(live_volume <= 0.0) return;

      // C-2: el porcentaje del parcial se aplica sobre el volumen VIVO de la
      // posición, no sobre el volumen original del plan. Si el usuario redujo
      // la posición manualmente (o un parcial previo ya cerró parte), calcular
      // sobre volume_original podía hacer que ClosePositionVolume escalara al
      // cierre TOTAL (el resto quedaba por debajo del mínimo) sin ninguna
      // confirmación explícita. Con el cálculo sobre el volumen vivo, un
      // parcial siempre cierra exactamente su porcentaje de lo que queda; y si
      // aun así el tramo restante resulta inferior al lote mínimo y el cierre
      // acaba siendo total, se emite una ALERTA explícita antes de enviar la
      // petición (ver ClosePositionVolume).
      double target = live_volume * (g_management[m].plan_stage_pct[s] / 100.0);

      bool will_close_entire_position = false;
      {
         bool   below_min_chk;
         double norm_target = NormalizeVolume(_Symbol, MathMin(target, live_volume),
                                              below_min_chk);
         double min_vol_chk = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double rem_chk     = live_volume - norm_target;

         will_close_entire_position = (below_min_chk || norm_target <= 0.0 ||
                                       (rem_chk > 0.0 && rem_chk < min_vol_chk - 1e-9));

         if(will_close_entire_position && target < live_volume * 0.999)
            Alert(StringFormat("%s: el parcial %d del ticket %I64u (%s%% de %s lotes) cerrará " +
                               "la posición COMPLETA porque el resto quedaría por debajo del " +
                               "mínimo del símbolo.",
                               APP_NAME, s + 1, g_management[m].ticket,
                               DoubleToString(g_management[m].plan_stage_pct[s], 1),
                               DoubleToString(live_volume, VolumeDecimalsFromStep(_Symbol))));
      }

      if(ClosePositionVolume(g_management[m].ticket, target,
                             StringFormat("parcial %d", s + 1)))
      {
         g_management[m].partial_resolved[s]        = true;
         g_management[m].partial_executed[s]        = true;
         g_management[m].partial_executed_volume[s] = MathMin(target, live_volume);
         g_management[m].partial_fail_count[s]      = 0;

         if(will_close_entire_position)
            LogExecution(StringFormat("El parcial %d del ticket %I64u cerró la posición " +
                                      "COMPLETA (el resto tras el parcial quedaba por debajo " +
                                      "del volumen mínimo).",
                                      s + 1, g_management[m].ticket), true);

         int zone_idx = FindPositionByPositionTicket(g_management[m].ticket);
         if(zone_idx >= 0)
         {
            g_positions[zone_idx].qty_valid = false;

            if(!PositionSelectByTicket(g_management[m].ticket))
            {
               MarkZoneClosed(zone_idx);
               MarkStateDirty();
               return;
            }

            UpdatePositionObjects(zone_idx);
         }

         MarkStateDirty();
         continue;
      }

      g_management[m].partial_fail_count[s]++;

      if(!g_management[m].partial_skipped_warned[s])
      {
         g_management[m].partial_skipped_warned[s] = true;
         LogExecution(StringFormat(
            "El parcial %d del ticket %I64u no se pudo ejecutar (intento %d).",
            s + 1, g_management[m].ticket, g_management[m].partial_fail_count[s]), true);
      }

      if(g_management[m].partial_fail_count[s] >= g_mgmt_max_failures)
      {
         g_management[m].plan_stage_active[s] = false;
         LogExecution(StringFormat(
            "El parcial %d del ticket %I64u se desactiva tras %d fallos consecutivos; " +
            "no se ejecutará automáticamente. Revíselo manualmente.",
            s + 1, g_management[m].ticket, g_management[m].partial_fail_count[s]), true);

         // A3/#6: si el BE estaba anclado a este parcial y no tiene disparador
         // alternativo por R, queda huérfano (nunca se activará). Avisar una vez.
         int be_stage = (int)MathMax(1, MathMin(PARTIAL_STAGES, g_management[m].plan_be_stage)) - 1;
         if(g_management[m].plan_be_on && !g_management[m].breakeven_done &&
            be_stage == s && g_management[m].plan_be_start_r <= 0.0 &&
            !g_management[m].be_orphan_warned)
         {
            g_management[m].be_orphan_warned = true;
            LogExecution(StringFormat(
               "AVISO: el break-even del ticket %I64u dependía del parcial %d y ha quedado " +
               "INACTIVO (sin trigger alternativo por R). La posición seguirá con SL original; " +
               "configure BreakEvenStartR o active el BE manualmente si procede.",
               g_management[m].ticket, s + 1), true);
         }
      }

      MarkStateDirty();
   }
}

bool BreakEvenTriggerMet(int m)
{
   if(!IsManagementValid(m)) return false;
   if(!g_management[m].plan_be_on) return false;
   if(g_management[m].breakeven_done) return false;

   int stage = (int)MathMax(1, MathMin(PARTIAL_STAGES, g_management[m].plan_be_stage)) - 1;

   bool stage_ready = g_management[m].plan_partials_on &&
                      g_management[m].plan_stage_active[stage] &&
                      g_management[m].partial_executed[stage];

   bool r_ready = (g_management[m].plan_be_start_r > 0.0 &&
                   CurrentRMultiple(m) >= g_management[m].plan_be_start_r);

   return (stage_ready || r_ready);
}

void ApplyBreakEven(int m)
{
   if(!IsManagementValid(m)) return;
   if(!BreakEvenTriggerMet(m)) return;
   if(!PositionSelectByTicket(g_management[m].ticket)) return;

   bool   is_long = (g_management[m].order_type == POSITION_TYPE_BUY);
   double tick    = GetTickSize(_Symbol);
   double offset  = (double)g_management[m].plan_be_offset_ticks * tick;

   double cost_distance = 0.0;
   if(g_management[m].plan_be_cover_costs)
   {
      double costs = PositionAccruedCosts(g_management[m].ticket);
      double volume = PositionGetDouble(POSITION_VOLUME);

      if(costs > 0.0 && volume > 0.0)
         cost_distance = MoneyToPriceDistance(_Symbol, is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                              volume, g_management[m].entry_price, costs);
   }

   double be_price = is_long
                     ? (g_management[m].entry_price + offset + cost_distance)
                     : (g_management[m].entry_price - offset - cost_distance);

   be_price = NormalizeToTick(be_price);

   double live_sl = PositionGetDouble(POSITION_SL);
   bool   improves = (live_sl <= 0.0) ||
                     (is_long ? (be_price > live_sl) : (be_price < live_sl));

   if(!improves)
   {
      g_management[m].breakeven_done = true;
      return;
   }

   MqlTick t;
   string  reason;
   if(!GetTradableTick(_Symbol, t, reason)) return;

   double close_price = is_long ? t.bid : t.ask;
   string distance_reason;

   if(!ValidateStopDistance(_Symbol, is_long ? PLANNER_POS_BUY : PLANNER_POS_SELL,
                            g_management[m].entry_price, close_price,
                            be_price, g_management[m].intended_tp, distance_reason))
   {
      return;
   }

   if(ModifyPositionLevels(g_management[m].ticket, be_price, g_management[m].intended_tp,
                           "break-even"))
   {
      g_management[m].breakeven_done = true;
      g_management[m].intended_sl    = be_price;

      LogExecution(StringFormat("Break-even aplicado en el ticket %I64u: SL a %s.",
                                g_management[m].ticket,
                                DoubleToString(be_price, _Digits)), false);

      int zone_idx = FindPositionByPositionTicket(g_management[m].ticket);
      if(zone_idx >= 0)
      {
         g_positions[zone_idx].sl_price = be_price;
         UpdatePositionObjects(zone_idx);
      }

      MarkStateDirty();
   }
}

void ApplyTrailing(int m)
{
   if(!IsManagementValid(m)) return;
   if(!g_management[m].plan_trail_on) return;
   if(g_management[m].plan_trail_method == TRAIL_NONE) return;
   if(!PositionSelectByTicket(g_management[m].ticket)) return;

   if(CurrentRMultiple(m) < g_management[m].plan_trail_start_r) return;

   MqlTick t;
   string  reason;
   if(!GetTradableTick(_Symbol, t, reason)) return;

   bool   is_long = (g_management[m].order_type == POSITION_TYPE_BUY);
   double tick    = GetTickSize(_Symbol);
   double price   = is_long ? t.bid : t.ask;

   double distance = (double)g_management[m].plan_trail_ticks * tick;

   if(g_management[m].plan_trail_method == TRAIL_ATR)
   {
      double atr;
      if(GetTrailingATR(atr) && atr > 0.0)
         distance = atr * g_management[m].plan_trail_atr_mult;
   }

   if(distance <= 0.0) return;

   double candidate = NormalizeToTick(is_long ? (price - distance) : (price + distance));
   double live_sl   = PositionGetDouble(POSITION_SL);
   double step      = (double)g_management[m].plan_trail_step_ticks * tick;

   if(live_sl > 0.0)
   {
      double improvement = is_long ? (candidate - live_sl) : (live_sl - candidate);
      if(improvement < step) return;
   }

   string distance_reason;
   if(!ValidateStopDistance(_Symbol, is_long ? PLANNER_POS_BUY : PLANNER_POS_SELL,
                            g_management[m].entry_price, price,
                            candidate, g_management[m].intended_tp, distance_reason))
      return;

   if(ModifyPositionLevels(g_management[m].ticket, candidate, g_management[m].intended_tp,
                           "trailing stop"))
   {
      g_management[m].trailing_active = true;
      g_management[m].intended_sl     = candidate;

      int zone_idx = FindPositionByPositionTicket(g_management[m].ticket);
      if(zone_idx >= 0)
      {
         g_positions[zone_idx].sl_price = candidate;
         UpdatePositionObjects(zone_idx);
      }

      MarkStateDirty();
   }
}

void VerifyProtectiveLevels()
{
   if(!g_is_primary_instance) return;
   if(!InpVerifyProtectiveLevels) return;

   for(int m = 0; m < ArraySize(g_management); m++)
   {
      if(!g_management[m].levels_pending) continue;
      if(!PositionSelectByTicket(g_management[m].ticket)) continue;

      double live_sl = PositionGetDouble(POSITION_SL);
      double live_tp = PositionGetDouble(POSITION_TP);
      double tol     = GetTickSize(_Symbol) / 2.0;

      if(MathAbs(live_sl - g_management[m].intended_sl) <= tol &&
         MathAbs(live_tp - g_management[m].intended_tp) <= tol)
      {
         g_management[m].levels_pending = false;
         g_management[m].level_attempts = 0;
         continue;
      }

      if(g_management[m].level_attempts >= InpMaxLevelRetries)
      {
         if(!g_management[m].level_alerted)
         {
            g_management[m].level_alerted = true;

            LogExecution(StringFormat("La posición %I64u sigue SIN los niveles previstos tras " +
                                      "%d intentos (SL vivo %s, previsto %s).",
                                      g_management[m].ticket, g_management[m].level_attempts,
                                      DoubleToString(live_sl, _Digits),
                                      DoubleToString(g_management[m].intended_sl, _Digits)), true);

            if(live_sl <= 0.0 && InpEmergencyCloseIfNoSL)
            {
               LogExecution(StringFormat("Cierre de emergencia del ticket %I64u por falta de SL.",
                                         g_management[m].ticket), true);
               bool closed = ClosePositionVolume(g_management[m].ticket,
                                                 PositionGetDouble(POSITION_VOLUME),
                                                 "cierre de emergencia sin SL");

               if(closed && !PositionSelectByTicket(g_management[m].ticket))
               {
                  g_management[m].level_alerted = true;
               }
               else
               {
                  g_management[m].level_alerted = false;
                  g_management[m].emergency_close_fail_count++;

                  LogExecution(StringFormat(
                     "Cierre de emergencia del ticket %I64u FALLÓ (intento %d); sigue sin SL " +
                     "y se reintentará.", g_management[m].ticket,
                     g_management[m].emergency_close_fail_count), true);

                  if(g_management[m].emergency_close_fail_count >= InpMaxLevelRetries)
                  {
                     LogExecution(StringFormat(
                        "El cierre de emergencia del ticket %I64u sigue fallando tras %d " +
                        "intentos; se escala a cierre total de la cuenta.",
                        g_management[m].ticket, g_management[m].emergency_close_fail_count), true);
                     RequestFlattenAll("cierre de emergencia sin SL reiteradamente fallido");
                  }
               }
            }
            else if(live_sl <= 0.0)
            {
               SetPanelStatus("ATENCIÓN: hay una posición sin Stop Loss en el servidor.", true);
            }
         }

         continue;
      }

      g_management[m].level_attempts++;

      ModifyPositionLevels(g_management[m].ticket,
                           g_management[m].intended_sl, g_management[m].intended_tp,
                           StringFormat("verificación de niveles %d/%d",
                                        g_management[m].level_attempts, InpMaxLevelRetries));
   }
}

void ManageOpenPositions()
{
   PruneClosedManagementRecords();

   if(!g_mgmt_allowed) return;

   ulong now = NowMs();

   for(int m = 0; m < ArraySize(g_management); m++)
   {
      if(!PositionSelectByTicket(g_management[m].ticket)) continue;

      if(g_management[m].next_attempt_ms > 0 && now < g_management[m].next_attempt_ms) continue;

      if(!PositionBelongsToEA(g_management[m].ticket))
      {
         if(!g_management[m].foreign_warned)
         {
            g_management[m].foreign_warned = true;
            LogExecution(StringFormat("El ticket %I64u ya no coincide con el magic del EA; " +
                                      "se deja de gestionar.", g_management[m].ticket), true);
         }
         continue;
      }

      int failures_before = g_management[m].fail_count;

      ApplyPartials(m);

      if(!PositionSelectByTicket(g_management[m].ticket)) continue;

      ApplyBreakEven(m);

      if(!PositionSelectByTicket(g_management[m].ticket)) continue;

      ApplyTrailing(m);

      if(g_management[m].fail_count > failures_before)
      {
         g_management[m].next_attempt_ms = now + (ulong)(g_mgmt_backoff_sec * 1000);

         if(g_management[m].fail_count >= g_mgmt_max_failures &&
            !g_management[m].failure_reported)
         {
            g_management[m].failure_reported = true;
            LogExecution(StringFormat("La gestión del ticket %I64u acumula %d fallos; " +
                                      "revise la posición manualmente.",
                                      g_management[m].ticket, g_management[m].fail_count), true);
         }
      }
      else
      {
         g_management[m].next_attempt_ms = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| ADOPCIÓN DE POSICIONES HUÉRFANAS                                 |
//+------------------------------------------------------------------+
void AdoptOrphanPositions()
{
   if(!InpAdoptOrphanPositions) return;
   if(!g_is_primary_instance)   return;

   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0) continue;
      if(!PositionBelongsToEA(ticket)) continue;
      if(FindManagementIndex(ticket) >= 0) continue;

      int zone_idx = FindPositionByPositionTicket(ticket);

      if(zone_idx < 0)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl   = PositionGetDouble(POSITION_SL);
         double tp   = PositionGetDouble(POSITION_TP);

         ENUM_PLANNER_POS_TYPE ptype = (type == POSITION_TYPE_BUY) ? PLANNER_POS_BUY
                                                                   : PLANNER_POS_SELL;

         datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         long id = CreateVisualPosition(ptype, open, open_time);
         if(id <= 0) continue;

         zone_idx = FindPositionById(id);
         if(zone_idx < 0) continue;

         double tick = GetTickSize(_Symbol);

         if(sl > 0.0) g_positions[zone_idx].sl_price = sl;
         if(tp > 0.0) g_positions[zone_idx].tp_price = tp;

         if(sl <= 0.0)
            g_positions[zone_idx].sl_price = (ptype == PLANNER_POS_BUY)
                                             ? open - g_sl_ticks * tick
                                             : open + g_sl_ticks * tick;

         if(tp <= 0.0)
            g_positions[zone_idx].tp_price = (ptype == PLANNER_POS_BUY)
                                             ? open + g_tp_ticks * tick
                                             : open - g_tp_ticks * tick;
      }

      RegisterPositionManagement(ticket, zone_idx);

      LogExecution(StringFormat("Posición huérfana %I64u adoptada por el EA.", ticket), false);
   }
}

void ReconcilePendingOrders()
{
   for(int i = 0; i < ArraySize(g_positions); i++)
   {
      if(g_positions[i].order_ticket == 0) continue;
      if(g_positions[i].is_executed)       continue;

      if(!OrderSelect(g_positions[i].order_ticket))
      {
         bool order_was_filled = false;
         if(HistoryOrderSelect(g_positions[i].order_ticket))
         {
            ENUM_ORDER_STATE hist_state =
               (ENUM_ORDER_STATE)HistoryOrderGetInteger(g_positions[i].order_ticket, ORDER_STATE);
            order_was_filled = (hist_state == ORDER_STATE_FILLED);
         }

         if(order_was_filled) continue;

         g_positions[i].order_ticket = 0;
         g_positions[i].is_locked    = false;
         UpdatePositionObjects(i);
         MarkStateDirty();
      }
   }

   if(g_pending_fill_order > 0 && g_pending_fill_ms > 0 &&
      NowMs() - g_pending_fill_ms > (ulong)PENDING_FILL_TIMEOUT_MS)
   {
      if(!OrderSelect(g_pending_fill_order))
      {
         g_pending_fill_order   = 0;
         g_pending_fill_zone_id = -1;
         g_pending_fill_ms      = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| LÍMITES DE CUENTA                                                |
//+------------------------------------------------------------------+
datetime DayStartWithResetHour(datetime reference)
{
   MqlDateTime dt;
   TimeToStruct(reference, dt);

   dt.hour = (int)MathMax(0, MathMin(23, InpLimitResetHour));
   dt.min  = 0;
   dt.sec  = 0;

   datetime start = StructToTime(dt);
   if(start > reference) start -= 86400;

   return start;
}

datetime WeekStartWithResetHour(datetime reference)
{
   datetime day_start = DayStartWithResetHour(reference);

   MqlDateTime dt;
   TimeToStruct(day_start, dt);

   datetime cursor = day_start;
   for(int i = 0; i < dt.day_of_week; i++)
      cursor = DayStartWithResetHour(cursor - 12 * 3600);

   return cursor;
}

double LimitReferenceValue()
{
   return (InpLimitBase == LIMIT_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE)
                                          : AccountInfoDouble(ACCOUNT_EQUITY);
}

double  g_cached_balance_ops[2]       = {0.0, 0.0};
bool    g_balance_ops_valid[2]        = {false, false};
datetime g_balance_ops_cached_from[2] = {0, 0};

void InvalidateBalanceOpsCache()
{
   g_balance_ops_valid[0] = false;
   g_balance_ops_valid[1] = false;
}

double BalanceOperationsSince(datetime from, int cache_slot = -1)
{
   if(!InpLimitIgnoreBalanceOps) return 0.0;

   bool use_cache = (cache_slot >= 0 && cache_slot < 2);
   if(use_cache && g_balance_ops_valid[cache_slot] &&
      g_balance_ops_cached_from[cache_slot] == from)
   {
      return g_cached_balance_ops[cache_slot];
   }

   if(!HistorySelect(from, TimeCurrent() + 60)) return 0.0;

   double total  = 0.0;
   int    deals  = HistoryDealsTotal();

   for(int i = 0; i < deals; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;

      long type = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BALANCE && type != DEAL_TYPE_CREDIT &&
         type != DEAL_TYPE_CORRECTION && type != DEAL_TYPE_BONUS)
         continue;

      total += HistoryDealGetDouble(deal, DEAL_PROFIT);
   }

   if(use_cache)
   {
      g_cached_balance_ops[cache_slot]      = total;
      g_balance_ops_valid[cache_slot]       = true;
      g_balance_ops_cached_from[cache_slot] = from;
   }

   return total;
}

void UpdateLimitBaselines(bool force)
{
   datetime now        = TimeCurrent();
   datetime day_start  = DayStartWithResetHour(now);
   datetime week_start = WeekStartWithResetHour(now);

   if(force || g_date_day_start != day_start)
   {
      g_date_day_start     = day_start;
      g_balance_day_start  = LimitReferenceValue();
      g_daily_warning_sent = false;

      if(g_limit_lock_scope == LIMIT_SCOPE_DAILY)
      {
         g_is_limit_locked   = false;
         g_limit_lock_reason = "";
         g_limit_lock_scope  = LIMIT_SCOPE_NONE;
         SetPanelStatus("Nuevo día: el límite diario se ha reiniciado.", false);
      }
   }

   if(force || g_date_week_start != week_start)
   {
      g_date_week_start     = week_start;
      g_balance_week_start  = LimitReferenceValue();
      g_weekly_warning_sent = false;

      if(g_limit_lock_scope == LIMIT_SCOPE_WEEKLY)
      {
         g_is_limit_locked   = false;
         g_limit_lock_reason = "";
         g_limit_lock_scope  = LIMIT_SCOPE_NONE;
         SetPanelStatus("Nueva semana: el límite semanal se ha reiniciado.", false);
      }
   }
}

void TriggerLimitLock(string reason, ENUM_LIMIT_SCOPE scope)
{
   if(!g_is_primary_instance) return;
   if(g_is_limit_locked) return;

   g_is_limit_locked   = true;
   g_limit_lock_reason = reason;
   g_limit_lock_scope  = scope;

   LogExecution("LÍMITE ALCANZADO — " + reason, true);
   SetPanelStatus("Límite alcanzado: " + reason, true);

   if(g_plan.active) AbortOrderPlan("Envío cancelado por límite de cuenta.", true);

   if(InpCloseOnLimit) RequestFlattenAll("límite de cuenta alcanzado");
   else                CancelAllPendingOrders("límite de cuenta alcanzado");
}

void EvaluateLimit(double baseline, double limit_amount, bool &warning_sent,
                   string scope_name, ENUM_LIMIT_SCOPE scope)
{
   if(limit_amount <= 0.0 || baseline <= 0.0) return;

   int cache_slot = (scope == LIMIT_SCOPE_DAILY) ? 0 : 1;
   double current = LimitReferenceValue() - BalanceOperationsSince(
                       (scope == LIMIT_SCOPE_DAILY) ? g_date_day_start : g_date_week_start,
                       cache_slot);

   double loss = baseline - current;
   if(loss <= 0.0) return;

   if(loss >= limit_amount)
   {
      TriggerLimitLock(StringFormat("pérdida %s de %s sobre un límite de %s.",
                                    scope_name, FormatMoneyFull(loss), FormatMoneyFull(limit_amount)),
                       scope);
      return;
   }

   if(!warning_sent && loss >= limit_amount * g_limit_warning_ratio)
   {
      warning_sent = true;
      LogExecution(StringFormat("Aviso: la pérdida %s (%s) alcanza el %.0f%% del límite (%s).",
                                scope_name, FormatMoneyFull(loss),
                                loss / limit_amount * 100.0, FormatMoneyFull(limit_amount)), true);
   }
}

void CheckAccountLimits()
{
   if(!g_is_primary_instance) return;

   UpdateLimitBaselines(false);

   EvaluateLimit(g_balance_day_start,  g_daily_loss_limit,  g_daily_warning_sent,
                 "diaria",  LIMIT_SCOPE_DAILY);
   EvaluateLimit(g_balance_week_start, g_weekly_loss_limit, g_weekly_warning_sent,
                 "semanal", LIMIT_SCOPE_WEEKLY);
}

void ForceLimitRecheck()
{
   CheckAccountLimits();
}

//+------------------------------------------------------------------+
//| CIERRE FORZOSO DE TODO (FLATTEN)                                 |
//+------------------------------------------------------------------+
void RequestFlattenAll(string reason)
{
   if(!g_is_primary_instance) return;
   if(g_flatten_pending) return;

   g_flatten_pending  = true;
   g_flatten_attempts = 0;
   g_flatten_reason   = reason;
   g_flatten_next_ms  = 0;

   LogExecution("Cierre total solicitado: " + reason + ".", true);
}

void ProcessFlatten()
{
   if(!g_is_primary_instance) return;
   if(!g_flatten_pending) return;

   ulong now = NowMs();
   if(g_flatten_next_ms > 0 && now < g_flatten_next_ms) return;

   g_flatten_attempts++;

   bool pending_cancelled = CancelAllPendingOrders("cierre total: " + g_flatten_reason);

   bool remaining = false;

   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0) continue;
      if(!PositionBelongsToEA(ticket)) continue;

      if(!ClosePositionVolume(ticket, PositionGetDouble(POSITION_VOLUME),
                              "cierre total: " + g_flatten_reason))
         remaining = true;
   }

   if(!remaining)
   {
      bool any_left = false;

      for(int p = PositionsTotal() - 1; p >= 0; p--)
      {
         ulong ticket = PositionGetTicket(p);
         if(ticket != 0 && PositionBelongsToEA(ticket)) { any_left = true; break; }
      }

       bool pending_left = false;
       for(int i = OrdersTotal() - 1; i >= 0; i--)
       {
          ulong order_ticket = OrderGetTicket(i);
          if(order_ticket == 0) continue;
          if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
          if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;

          pending_left = true;
          break;
       }

       if(!any_left && pending_cancelled && !pending_left)
      {
         g_flatten_pending = false;
         LogExecution("Cierre total completado.", false);
         SetPanelStatus("Cierre total completado.", false);
         MarkStateDirty();
         return;
      }
   }

   bool slow = (g_flatten_attempts > FLATTEN_MAX_PASSES);
   g_flatten_next_ms = now + (ulong)(slow ? FLATTEN_SLOW_RETRY_MS : FLATTEN_RETRY_MS);

   if(g_flatten_attempts % FLATTEN_ALERT_EVERY == 0)
      LogExecution(StringFormat("El cierre total lleva %d intentos sin completarse (%s). " +
                                "Intervenga manualmente si persiste.",
                                g_flatten_attempts, g_flatten_reason), true);
}

//+------------------------------------------------------------------+
//| INPUTS EN VIVO - COPIA Y SANEAMIENTO                             |
//+------------------------------------------------------------------+
void ApplyInputsToLive()
{
   InpVolumeMode           = InpVolumeMode_Default;
   InpFixedVolume          = InpFixedVolume_Default;
   InpRiskPercent          = InpRiskPercent_Default;
   InpRiskBase             = InpRiskBase_Default;
   InpRiskCommissionPerLot = InpRiskCommissionPerLot_Default;

   InpDefaultTPTicks = InpDefaultTPTicks_Default;
   InpDefaultSLTicks = InpDefaultSLTicks_Default;
   InpZoneWidthBars  = InpZoneWidthBars_Default;
   InpMaxClosedZones = InpMaxClosedZones_Default;

   InpColorTP          = InpColorTP_Default;
   InpColorSL          = InpColorSL_Default;
   InpColorEntry       = InpColorEntry_Default;
   InpColorStats       = InpColorStats_Default;
   InpZoneTransparency = InpZoneTransparency_Default;
   InpFontSizeStats    = InpFontSizeStats_Default;
   InpLineWidth        = InpLineWidth_Default;
   InpShowLevels       = InpShowLevels_Default;
   InpShowPnL          = InpShowPnL_Default;

   InpMagicNumber             = InpMagicNumber_Default;
   InpExecMode                = InpExecMode_Default;
   InpEntryToleranceTicks     = InpEntryToleranceTicks_Default;
   InpPendingExpiryMinutes    = InpPendingExpiryMinutes_Default;
   InpMaxDeviation            = InpMaxDeviation_Default;
   InpMaxRetries              = InpMaxRetries_Default;
   InpBackoffBase             = InpBackoffBase_Default;
   InpMaxVolDeviationPct      = InpMaxVolDeviationPct_Default;
   InpKeepDistancesOnFillShift = InpKeepDistancesOnFillShift_Default;

   InpManagementInterval = InpManagementInterval_Default;
   InpEnablePartials     = InpEnablePartials_Default;
   InpPartial1Multiple   = InpPartial1Multiple_Default;
   InpPartial1Percent    = InpPartial1Percent_Default;
   InpPartial2Multiple   = InpPartial2Multiple_Default;
   InpPartial2Percent    = InpPartial2Percent_Default;
   InpPartial3Multiple   = InpPartial3Multiple_Default;
   InpPartial3Percent    = InpPartial3Percent_Default;

   InpEnableBreakEven      = InpEnableBreakEven_Default;
   InpBreakEvenTrigger     = InpBreakEvenTrigger_Default;
   InpBreakEvenStartR      = InpBreakEvenStartR_Default;
   InpBreakEvenOffsetTicks = InpBreakEvenOffsetTicks_Default;
   InpBreakEvenCoverCosts  = InpBreakEvenCoverCosts_Default;

   InpEnableTrailing        = InpEnableTrailing_Default;
   InpTrailingStartR        = InpTrailingStartR_Default;
   InpTrailingStepTicks     = InpTrailingStepTicks_Default;
   InpTrailingMethod        = InpTrailingMethod_Default;
   InpTrailingTicks         = InpTrailingTicks_Default;
   InpTrailingATRTimeframe  = InpTrailingATRTimeframe_Default;
   InpTrailingATRPeriod     = InpTrailingATRPeriod_Default;
   InpTrailingATRMultiplier = InpTrailingATRMultiplier_Default;

   InpVerifyProtectiveLevels = InpVerifyProtectiveLevels_Default;
   InpMaxLevelRetries        = InpMaxLevelRetries_Default;
   InpEmergencyCloseIfNoSL   = InpEmergencyCloseIfNoSL_Default;

   InpManagementRetryBackoffSec = InpManagementRetryBackoffSec_Default;
   InpManagementMaxFailures     = InpManagementMaxFailures_Default;
   InpAdoptOrphanPositions      = InpAdoptOrphanPositions_Default;

   InpAllowNettingTrading    = InpAllowNettingTrading_Default;
   InpAllowNettingManagement = InpAllowNettingManagement_Default;

   InpEnablePushNotifications = InpEnablePushNotifications_Default;

   g_daily_loss_limit        = InpDailyLossLimit_Default;
   g_weekly_loss_limit       = InpWeeklyLossLimit_Default;
   InpLimitBase             = InpLimitBase_Default;
   InpCloseOnLimit          = InpCloseOnLimit_Default;
   InpLimitWarningLevel     = InpLimitWarningLevel_Default;
   InpLimitIgnoreBalanceOps = InpLimitIgnoreBalanceOps_Default;
   InpLimitResetHour        = InpLimitResetHour_Default;

   InpPanelZoom             = InpPanelZoom_Default;
   InpPanelWidth            = InpPanelWidth_Default;
   InpObjectPrefix          = (InpObjectPrefix_Default == "") ? "PPLN" : InpObjectPrefix_Default;
   InpHideNativeTradeLevels = InpHideNativeTradeLevels_Default;
   InpEnableAutoTemplate    = InpEnableAutoTemplate_Default;

   InpInstanceTag              = InpInstanceTag_Default;
   InpLoadSavedConfig          = InpLoadSavedConfig_Default;
   InpForcePrimaryOnLockFailure = InpForcePrimaryOnLockFailure_Default;
   InpStrictInstanceLock       = InpStrictInstanceLock_Default;
   InpMaxOpenPositions         = InpMaxOpenPositions_Default;

   g_volume                 = InpFixedVolume;
   g_effective_risk_percent = InpRiskPercent;
   g_tp_ticks               = InpDefaultTPTicks;
   g_sl_ticks               = InpDefaultSLTicks;
   g_zone_width_bars        = InpZoneWidthBars;
   g_closed_zone_limit      = InpMaxClosedZones;
   g_transparency           = InpZoneTransparency;
   g_font_size_stats        = InpFontSizeStats;
   g_line_width             = InpLineWidth;
   g_show_levels            = InpShowLevels;
   g_show_pnl               = InpShowPnL;

   g_max_deviation         = InpMaxDeviation;
   g_max_retries           = InpMaxRetries;
   g_backoff_base          = InpBackoffBase;
   g_max_vol_dev_pct       = InpMaxVolDeviationPct;
   g_entry_tolerance_ticks = InpEntryToleranceTicks;

   g_management_interval = InpManagementInterval;
   g_mgmt_backoff_sec    = InpManagementRetryBackoffSec;
   g_mgmt_max_failures   = InpManagementMaxFailures;

   g_enable_partials  = InpEnablePartials;
   g_enable_breakeven = InpEnableBreakEven;
   g_enable_trailing  = InpEnableTrailing;

   g_partial_mult[0] = InpPartial1Multiple;  g_partial_pct[0] = InpPartial1Percent;
   g_partial_mult[1] = InpPartial2Multiple;  g_partial_pct[1] = InpPartial2Percent;
   g_partial_mult[2] = InpPartial3Multiple;  g_partial_pct[2] = InpPartial3Percent;

   for(int s = 0; s < PARTIAL_STAGES; s++)
      g_partial_enabled[s] = false;

   g_be_offset_ticks         = InpBreakEvenOffsetTicks;
   g_be_start_r              = InpBreakEvenStartR;
   g_trailing_ticks          = InpTrailingTicks;
   g_trailing_step_ticks     = InpTrailingStepTicks;
   g_trailing_atr_period     = InpTrailingATRPeriod;
   g_trailing_atr_multiplier = InpTrailingATRMultiplier;
   g_trailing_start_r        = InpTrailingStartR;

   g_trail_atr_tf = (InpTrailingATRTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period
                                                                : InpTrailingATRTimeframe;

   g_limit_warning_ratio = MathMax(0.1, MathMin(1.0, InpLimitWarningLevel / 100.0));

   g_panel_zoom  = InpPanelZoom;
   g_panel_width = InpPanelWidth;
}

double MaxPanelZoomForChartHeight()
{
   const double ZOOM_HARD_CAP = 2.0;

   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(chart_h <= 0) return ZOOM_HARD_CAP;

   int rows_h       = SETTINGS_FIELDS * SETTINGS_ROW_STEP;
   int total_h_unit = SETTINGS_HEADER_H + rows_h + SETTINGS_FOOTER_H + 2 * SETTINGS_MARGIN;
   if(total_h_unit <= 0) return ZOOM_HARD_CAP;

   double margin    = 2.0 * PANEL_MARGIN + 40.0;
   double available = MathMax(200.0, (double)chart_h - margin);

   return MathMax(0.7, MathMin(ZOOM_HARD_CAP, available / (double)total_h_unit));
}

void ClampLiveSettings()
{
   g_tp_ticks            = (int)MathMax(1, MathMin(1000000, g_tp_ticks));
   g_sl_ticks            = (int)MathMax(1, MathMin(1000000, g_sl_ticks));
   g_zone_width_bars     = (int)MathMax(1, MathMin(500, g_zone_width_bars));
   g_closed_zone_limit   = (int)MathMax(0, MathMin(500, g_closed_zone_limit));
   g_transparency        = (int)MathMax(0, MathMin(100, g_transparency));
   g_font_size_stats     = (int)MathMax(6, MathMin(20, g_font_size_stats));
   g_line_width          = (int)MathMax(1, MathMin(5, g_line_width));
   g_max_deviation       = (int)MathMax(0, MathMin(1000, g_max_deviation));
   g_max_retries         = (int)MathMax(1, MathMin(20, g_max_retries));
   g_backoff_base        = (int)MathMax(50, MathMin(5000, g_backoff_base));
   g_max_vol_dev_pct     = MathMax(0.1, MathMin(100.0, g_max_vol_dev_pct));
   g_entry_tolerance_ticks = MathMax(0.0, MathMin(100000.0, g_entry_tolerance_ticks));

   g_management_interval = (int)MathMax(1, MathMin(60, g_management_interval));
   g_mgmt_backoff_sec    = (int)MathMax(1, MathMin(600, g_mgmt_backoff_sec));
   g_mgmt_max_failures   = (int)MathMax(1, MathMin(1000, g_mgmt_max_failures));

   g_be_offset_ticks         = (int)MathMax(0, MathMin(100000, g_be_offset_ticks));
   g_be_start_r              = MathMax(0.0, MathMin(100.0, g_be_start_r));
   g_trailing_ticks          = (int)MathMax(1, MathMin(1000000, g_trailing_ticks));
   g_trailing_step_ticks     = (int)MathMax(1, MathMin(100000, g_trailing_step_ticks));
   g_trailing_atr_period     = (int)MathMax(1, MathMin(500, g_trailing_atr_period));
   g_trailing_atr_multiplier = MathMax(0.1, MathMin(20.0, g_trailing_atr_multiplier));
   g_trailing_start_r        = MathMax(0.0, MathMin(100.0, g_trailing_start_r));

   double max_feasible_zoom = MaxPanelZoomForChartHeight();
   g_panel_zoom  = MathMax(0.7, MathMin(max_feasible_zoom, g_panel_zoom));
   g_panel_width = (int)MathMax(PANEL_MIN_WIDTH, MathMin(800, g_panel_width));

   if(g_effective_risk_percent >= 0.0)
      g_effective_risk_percent = MathMax(0.01, MathMin(100.0, g_effective_risk_percent));

   bool below_min;
   double normalized = NormalizeVolume(_Symbol, g_volume, below_min);
   if(!below_min && normalized > 0.0) g_volume = normalized;
}

void ResetRuntimeState()
{
   ResetOrderPlan();

   g_selected_id = -1;
   g_hover_id    = -1;

   g_drag_mode  = DRAG_NONE;
   g_drag_id    = -1;
   g_drag_stage = -1;

   g_panel_dragging    = false;
   g_settings_dragging = false;

   g_flatten_pending  = false;
   g_flatten_attempts = 0;
   g_flatten_reason   = "";

   g_pending_fill_order   = 0;
   g_pending_fill_zone_id = -1;
   g_pending_fill_ms      = 0;

   ArrayResize(g_positions, 0, INITIAL_POSITIONS_CAPACITY);
   ArrayResize(g_management, 0, INITIAL_MANAGEMENT_CAPACITY);

   g_search_cache.Reset();
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   ResetRuntimeState();
   InitializeArrays();
   g_icon_font_usable = DetectIconFontUsable();
   ApplyInputsToLive();
   ClampLiveSettings();
   InitSettingsMetadata();

   if(!SymbolSelect(_Symbol, true))
   {
      PrintFormat("%s: ERROR — no se pudo seleccionar el símbolo %s.", APP_NAME, _Symbol);
      return INIT_FAILED;
   }

   if(GetTickSize(_Symbol) <= 0.0)
   {
      PrintFormat("%s: ERROR — %s no reporta un tamaño de tick válido.", APP_NAME, _Symbol);
      return INIT_FAILED;
   }

   if(!AcquireInstanceLock() && !g_is_primary_instance && !InpForcePrimaryOnLockFailure)
   {
      // M-4: si el bloqueo quedó en manos de OTRA instancia viva, continuar
      // aquí sería contradictorio: más abajo se restaura el estado persistido,
      // se adoptan huérfanas y la otra primaria podría sobreescribir este
      // archivo de estado. El gráfico arranca DIRECTAMENTE en modo observador
      // (solo visualización; OnTimer reintenta la promoción cada
      // INSTANCE_LOCK_RETRY_MS) y no escribe estado ni configuración.
      BuildPanel();
      RebuildAllZoneObjects();
      if(!IsSilentTesterMode())
      {
         UpdatePanelInfo();
         ChartRedraw(0);
      }

      SetPanelStatus("Modo observador: otra instancia gestiona este símbolo/magic. " +
                     "Este gráfico no ejecuta, no gestiona y no guarda estado.", true);
      PrintFormat("%s: OnInit completado en MODO OBSERVADOR por conflicto de bloqueo.", APP_NAME);
      return INIT_SUCCEEDED;
   }

   LoadSavedConfig();
   ClampLiveSettings();

   ConfigureTradeObject();
   RecomputeManagementFlags();
   ApplyAccountModePolicy();

   SaveChartSettings();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   HideNativeTradeLevels();

   if(InpForceResetStateNow)
   {
      // M-5: borrar el estado con posiciones vivas del magic en mercado era
      // una contradicción: las huérfanas se re-adoptaban sin plan (parciales/
      // BE/trailing congelados perdidos) y los límites diarios se reseteaban
      // involuntariamente. Ahora el borrado forzado SOLO se ejecuta si no hay
      // posiciones vivas; con posiciones abiertas se conserva el estado y se
      // avisa (use CERRAR TODO primero si de verdad quiere partir de cero).
      if(HasLiveEAPositions())
      {
         PrintFormat("%s: InpForceResetStateNow=true se IGNORA porque hay posiciones vivas " +
                     "con el magic %d; forzar el borrado dejaría esas posiciones sin plan de " +
                     "gestión y reiniciaría los límites diarios. Ciérrelas primero si desea " +
                     "un arranque limpio.", APP_NAME, InpMagicNumber);
         if(InpEnablePushNotifications && !IsTesterContext())
            SendNotification(StringFormat("%s %s: InpForceResetStateNow ignorado (hay " +
                                          "posiciones vivas).", APP_NAME, _Symbol));
      }
      else
      {
         PrintFormat("%s: InpForceResetStateNow=true — se fuerza un arranque limpio, " +
                     "descartando cualquier estado guardado.", APP_NAME);
         ClearPersistedPositionsState();
      }
   }

   LoadPositionsState();

   BuildPanel();
   RebuildAllZoneObjects();

   // #3: si los baselines se restauraron del estado (mismo día/semana), NO se
   // fuerzan a equity actual; UpdateLimitBaselines(false) solo los recalcula
   // si cambió el periodo. Si no se restauraron, force=true como antes.
   UpdateLimitBaselines(!g_limit_baseline_restored);
   AdoptOrphanPositions();

   if(InpTrailingMethod == TRAIL_ATR && g_enable_trailing) EnsureTrailingATRHandle();

   ApplyAutoTemplate();

   ulong now = NowMs();
   g_next_mgmt_ms       = now;
   g_next_adopt_ms      = now + ADOPT_CHECK_MS;
   g_next_native_ms     = now + NATIVE_LEVELS_CHECK_MS;
   g_next_heartbeat_ms  = now + INSTANCE_HB_PERIOD_MS;
   g_next_flush_ms      = now + STATE_FLUSH_MS;
   g_next_reconcile_ms  = now + PROPAGATE_CHECK_MS;
   g_next_lock_retry_ms = now + (ulong)INSTANCE_LOCK_RETRY_MS;
   g_next_levels_ms     = now + LEVELS_CHECK_MS;
   g_next_panel_slow_ms = now + PANEL_SLOW_REFRESH_MS;

   EventSetMillisecondTimer(PANEL_FAST_REFRESH_MS);

   SetPanelStatus(g_is_primary_instance
                  ? "EA iniciado. Pruebe siempre en demo antes de operar en real."
                  : "Modo observador: este gráfico no ejecuta ni gestiona operaciones.",
                  !g_is_primary_instance);

   if(!IsSilentTesterMode())
   {
      UpdatePanelInfo();
      ChartRedraw(0);
   }

   return INIT_SUCCEEDED;
}

bool HasLiveEAPositions()
{
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0) continue;
      if(PositionBelongsToEA(ticket)) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_plan.active)
      LogExecution("El EA se descarga con un envío de orden en curso; verifique el terminal.",
                   true);

   if(reason == REASON_REMOVE && InpClearStateOnRemove)
   {
      if(HasLiveEAPositions())
      {
         PrintFormat("%s: se ignora InpClearStateOnRemove porque hay posiciones vivas con el " +
                     "magic %d; se conserva el estado guardado para no duplicar/re-ejecutar " +
                     "parciales al volver a adjuntar el EA.", APP_NAME, InpMagicNumber);
         SavePositionsState();
      }
      else
      {
         ClearPersistedPositionsState();
      }
   }
   else
   {
      SavePositionsState();
   }

   if(g_is_primary_instance) SaveLiveConfig();

   DestroySettingsPanel();
   DestroyPanel();
   DeleteAllZoneObjects();

   ReleaseIndicatorHandles();
   RestoreChartSettings();
   ReleaseInstanceLock();

   ChartRedraw(0);

   PrintFormat("%s: descargado (motivo %d).", APP_NAME, reason);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   InvalidatePricePerPixel();

   SynchronizeLockedDraftZones();

   if(g_plan.active) ProcessOrderPlan();

   // M-1: reintentos diferidos de cancelación sin bloquear el hilo del EA.
   ProcessPendingCancels();

   ulong now = NowMs();

   if(now >= g_next_limits_ms)
   {
      g_next_limits_ms = now + LIMITS_CHECK_MS;
      CheckAccountLimits();
   }

   ProcessFlatten();

   if(now >= g_next_mgmt_ms)
   {
      g_next_mgmt_ms = now + (ulong)(g_management_interval * 1000);
      ManageOpenPositions();
   }

   if(now >= g_next_levels_ms)
   {
      g_next_levels_ms = now + LEVELS_CHECK_MS;
      VerifyProtectiveLevels();
   }

   if(g_show_pnl) MarkPanelDirty();

   if(!IsSilentTesterMode() && g_needs_redraw)
   {
      ChartRedraw(0);
      g_needs_redraw = false;
   }
}

//+------------------------------------------------------------------+
//| OnTimer                                                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   ulong now = NowMs();

   if(g_pending_panel_rebuild)
   {
      g_pending_panel_rebuild = false;
      DestroyPanel();
      BuildPanel();

      if(g_settings_panel_open)
      {
         DestroySettingsPanel();
         BuildSettingsPanel();
      }
   }

   if(g_pending_zone_rebuild)
      RebuildAllZoneObjects();

   if(g_chart_change_pending &&
      now - g_last_chart_change_ms >= (ulong)CHART_CHANGE_THROTTLE_MS)
   {
      g_chart_change_pending = false;
      g_last_chart_change_ms = now;
      RecalculateAllPositions();
   }

   if(g_plan.active) ProcessOrderPlan();

   // M-1: los reintentos de cancelación también avanzan con el timer, para
   // que una orden encolada se resuelva aunque el símbolo esté ilíquido.
   ProcessPendingCancels();

   ProcessFlatten();

   if(now >= g_next_limits_ms)
   {
      g_next_limits_ms = now + LIMITS_CHECK_MS;
      CheckAccountLimits();
   }

   if(now >= g_next_mgmt_ms)
   {
      g_next_mgmt_ms = now + (ulong)(g_management_interval * 1000);
      ManageOpenPositions();
   }

   if(now >= g_next_levels_ms)
   {
      g_next_levels_ms = now + LEVELS_CHECK_MS;
      VerifyProtectiveLevels();
   }

   if(now >= g_next_reconcile_ms)
   {
      g_next_reconcile_ms = now + PROPAGATE_CHECK_MS;
      ReconcilePendingOrders();
   }

   if(now >= g_next_adopt_ms)
   {
      g_next_adopt_ms = now + ADOPT_CHECK_MS;
      AdoptOrphanPositions();
      ApplyAccountModePolicy();
   }

   if(!g_is_primary_instance && now >= g_next_lock_retry_ms)
   {
      g_next_lock_retry_ms = now + (ulong)INSTANCE_LOCK_RETRY_MS;
      RetryInstanceLockIfObserver();
   }

   if(g_flat_arm_until_ms > 0 && now > g_flat_arm_until_ms)
   {
      DisarmDestructiveButtons();
      SetPanelStatus("Confirmación de CERRAR TODO expirada; no se ha cerrado nada.", false);
   }

   if(g_cancel_arm_until_ms > 0 && now > g_cancel_arm_until_ms)
   {
      DisarmDestructiveButtons();
      SetPanelStatus("Confirmación de CANCELAR expirada; no se ha cancelado nada.", false);
   }

   if(now >= g_next_native_ms)
   {
      g_next_native_ms = now + NATIVE_LEVELS_CHECK_MS;
      HideNativeTradeLevels();
   }

   if(now >= g_next_heartbeat_ms)
   {
      g_next_heartbeat_ms = now + INSTANCE_HB_PERIOD_MS;
      WriteInstanceHeartbeat();
      // C1: la instancia primaria revalida periódicamente que el lock sigue
      // siendo suyo (otro chart no lo tomó). Si lo perdió, se degrada sola
      // a modo observador antes de seguir gestionando/ejecutando.
      VerifyLockOwnership();
   }

   if(g_state_dirty && now >= g_next_flush_ms)
   {
      g_next_flush_ms = now + STATE_FLUSH_MS;
      SavePositionsState();
   }

   if(now >= g_next_panel_slow_ms)
   {
      g_next_panel_slow_ms = now + PANEL_SLOW_REFRESH_MS;
      MarkPanelDirty();
   }

   UpdateUI();
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.symbol != "" && trans.symbol != _Symbol) return;

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(!HistoryDealSelect(trans.deal)) { MarkStateDirty(); return; }

      long deal_type_for_cache = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
      if(deal_type_for_cache == DEAL_TYPE_BALANCE || deal_type_for_cache == DEAL_TYPE_CREDIT ||
         deal_type_for_cache == DEAL_TYPE_CORRECTION || deal_type_for_cache == DEAL_TYPE_BONUS)
      {
         InvalidateBalanceOpsCache();
      }

      // C-1: los deals ajenos al magic también cambian el estado de la cuenta
      // (y pueden afectar a posiciones adoptadas o compartidas). Antes se
      // retornaba sin marcar el estado como sucio, dejando una ventana de
      // riesgo ante reinicios (el estado guardado quedaba obsoleto sin
      // volcarse). Se marca SIEMPRE, y solo se omite la lógica específica del
      // EA para deals de otro magic.
      if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber)
      {
         MarkStateDirty();
         MarkPanelDirty();
         return;
      }

      ulong position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      long  entry       = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

      if(entry == DEAL_ENTRY_IN && position_id > 0)
      {
         int zone_idx = FindPositionByPositionTicket(position_id);

         if(zone_idx < 0)
         {
            ulong order_ticket = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
            zone_idx = FindPositionByOrderTicket(order_ticket);

            if(zone_idx < 0 && g_pending_fill_zone_id >= 0)
               zone_idx = FindPositionById(g_pending_fill_zone_id);
         }

         if(zone_idx >= 0 && PositionSelectByTicket(position_id))
         {
            g_positions[zone_idx].order_ticket = 0;
            RegisterPositionManagement(position_id, zone_idx);

            g_pending_fill_order   = 0;
            g_pending_fill_zone_id = -1;
            g_pending_fill_ms      = 0;

            SetPanelStatus(StringFormat("Orden ejecutada: posición %I64u activa.", position_id),
                           false);
         }
      }

      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
         int zone_idx = FindPositionByPositionTicket(position_id);

         if(zone_idx >= 0 && !PositionSelectByTicket(position_id))
            MarkZoneClosed(zone_idx);

         ForceLimitRecheck();
      }

      MarkStateDirty();
      MarkPanelDirty();
      return;
   }

   if(trans.type == TRADE_TRANSACTION_ORDER_DELETE ||
      trans.type == TRADE_TRANSACTION_HISTORY_ADD)
   {
      int zone_idx = FindPositionByOrderTicket(trans.order);

      if(zone_idx >= 0 && !g_positions[zone_idx].is_executed && !OrderSelect(trans.order))
      {
         bool order_was_filled = false;
         if(HistoryOrderSelect(trans.order))
         {
            ENUM_ORDER_STATE hist_state =
               (ENUM_ORDER_STATE)HistoryOrderGetInteger(trans.order, ORDER_STATE);
            order_was_filled = (hist_state == ORDER_STATE_FILLED);
         }

         if(order_was_filled)
         {
            return;
         }

         g_positions[zone_idx].order_ticket = 0;
         g_positions[zone_idx].is_locked    = false;
         UpdatePositionObjects(zone_idx);

         MarkStateDirty();
         MarkPanelDirty();
      }
   }
}
//+------------------------------------------------------------------+
