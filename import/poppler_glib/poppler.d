module poppler_glib.poppler;

import gtkc.gobject;

enum PopplerError
{
  POPPLER_ERROR_INVALID,
  POPPLER_ERROR_ENCRYPTED,
  POPPLER_ERROR_OPEN_FILE,
  POPPLER_ERROR_BAD_CATALOG,
  POPPLER_ERROR_DAMAGED
}

enum PopplerOrientation
{
  POPPLER_ORIENTATION_PORTRAIT,
  POPPLER_ORIENTATION_LANDSCAPE,
  POPPLER_ORIENTATION_UPSIDEDOWN,
  POPPLER_ORIENTATION_SEASCAPE
}

enum PopplerPageTransitionType
{
  POPPLER_PAGE_TRANSITION_REPLACE,
  POPPLER_PAGE_TRANSITION_SPLIT,
  POPPLER_PAGE_TRANSITION_BLINDS,
  POPPLER_PAGE_TRANSITION_BOX,
  POPPLER_PAGE_TRANSITION_WIPE,
  POPPLER_PAGE_TRANSITION_DISSOLVE,
  POPPLER_PAGE_TRANSITION_GLITTER,
  POPPLER_PAGE_TRANSITION_FLY,
  POPPLER_PAGE_TRANSITION_PUSH,
  POPPLER_PAGE_TRANSITION_COVER,
  POPPLER_PAGE_TRANSITION_UNCOVER,
  POPPLER_PAGE_TRANSITION_FADE
}

enum PopplerPageTransitionAlignment
{
  POPPLER_PAGE_TRANSITION_HORIZONTAL,
  POPPLER_PAGE_TRANSITION_VERTICAL
}

enum PopplerPageTransitionDirection
{
  POPPLER_PAGE_TRANSITION_INWARD,
  POPPLER_PAGE_TRANSITION_OUTWARD
}

enum PopplerSelectionStyle
{
  POPPLER_SELECTION_GLYPH,
  POPPLER_SELECTION_WORD,
  POPPLER_SELECTION_LINE
}

enum PopplerPrintFlags /*< flags >*/
{
  POPPLER_PRINT_DOCUMENT          = 0,
  POPPLER_PRINT_MARKUP_ANNOTS     = 1 << 0,
  POPPLER_PRINT_STAMP_ANNOTS_ONLY = 1 << 1,
  POPPLER_PRINT_ALL               = POPPLER_PRINT_MARKUP_ANNOTS
}

enum PopplerFindFlags/*< flags >*/
{
  POPPLER_FIND_DEFAULT          = 0,
  POPPLER_FIND_CASE_SENSITIVE   = 1 << 0,
  POPPLER_FIND_BACKWARDS        = 1 << 1,
  POPPLER_FIND_WHOLE_WORDS_ONLY = 1 << 2
} 

struct PopplerDocument;
struct PopplerIndexIter;
struct PopplerFontsIter;
struct PopplerLayersIter;
struct PopplerPoint;
struct PopplerRectangle;
struct PopplerTextAttributes;
struct PopplerColor;
struct PopplerLinkMapping;
struct PopplerPageTransition;
struct PopplerImageMapping;
struct PopplerFormFieldMapping;
struct PopplerAnnotMapping;
struct PopplerPage;
struct PopplerFontInfo;
struct PopplerLayer;
struct PopplerPSFile;
union PopplerAction;
struct PopplerDest;
struct PopplerActionLayer;
struct PopplerFormField;
struct PopplerAttachment;
struct PopplerMovie;
struct PopplerMedia;
struct PopplerAnnot;
struct PopplerAnnotMarkup;
struct PopplerAnnotText;
struct PopplerAnnotTextMarkup;
struct PopplerAnnotFreeText;
struct PopplerAnnotFileAttachment;
struct PopplerAnnotMovie;
struct PopplerAnnotScreen;
struct PopplerAnnotCalloutLine;
struct PopplerAnnotLine;
struct PopplerAnnotCircle;
struct PopplerAnnotSquare;
struct PopplerQuadrilateral;
struct PopplerStructureElement;
struct PopplerStructureElementIter;
struct PopplerTextSpan;

enum PopplerBackend
{
  POPPLER_BACKEND_UNKNOWN,
  POPPLER_BACKEND_SPLASH,
  POPPLER_BACKEND_CAIRO
} 

extern (C) {
    PopplerBackend poppler_get_backend ();
    const(char *)   poppler_get_version ();
}

