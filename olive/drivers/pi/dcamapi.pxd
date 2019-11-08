cdef extern from 'lib/dcamapi4.h':
    ctypedef int            int32
    ctypedef unsigned int   _ui32

    ctypedef void* HDCAM

    enum DCAMERR:
        ##
        ## status error
        ##
        DCAMERR_BUSY,           # API cannot process in busy state
        DCAMERR_NOTREADY,       # API requires ready state
        DCAMERR_NOTSTABLE,      # API requires stable or unstable state
        DCAMERR_UNSTABLE,       # API requires stable or unstable state
        DCAMERR_NOTBUSY,        # API requires busy state

        DCAMERR_EXCLUDED,       # some resource is exclusive and already used

        #: something happens near cooler
        DCAMERR_COOLINGTROUBLE,
        #: no trigger when necessary. Some camera supports this error
        DCAMERR_NOTRIGGER,
        #: camera warns its temperature
        DCAMERR_TEMPERATURE_TROUBLE,
        #: input too frequent trigger. Some camera supports this error
        DCAMERR_TOOFREQUENTTRIGGER,

        ##
        ## wait error
        ##
        #: abort process
        DCAMERR_ABORT,
        #: timeout
        DCAMERR_TIMEOUT,
        #: frame data is lost
        DCAMERR_LOSTFRAME,
        #: frame is lost but reason is low level driver's bug
        DCAMERR_MISSINGFRAME_TROUBLE,
        #: hpk format data is invalid data
        DCAMERR_INVALIDIMAGE,


        ##
        ## initialization error
        ##
        #: not enough resource except memory
        DCAMERR_NORESOURCE,
        #: not enough memory
        DCAMERR_NOMEMORY,
        #: no sub module
        DCAMERR_NOMODULE,
        #: no driver
        DCAMERR_NODRIVER,
        #: no camera
        DCAMERR_NOCAMERA,
        #: no grabber
        DCAMERR_NOGRABBER,
        #: no combination on registry
        DCAMERR_NOCOMBINATION,


        #: DEPRECATED
        DCAMERR_FAILOPEN,
        #: dcam_init() found invalid module
        DCAMERR_INVALIDMODULE,
        #: invalid serial port
        DCAMERR_INVALIDCOMMPORT,
        #: the bus or driver are not available
        DCAMERR_FAILOPENBUS,
        #: camera report error during opening
        DCAMERR_FAILOPENCAMERA,
        #: need to update frame grabber firmware to use the camera
        DCAMERR_FRAMEGRABBER_NEEDS_FIRMWAREUPDATE,


        ##
        ## calling error
        ##
        #: invalid camera
        DCAMERR_INVALIDCAMERA,
        #: invalid camera handle
        DCAMERR_INVALIDHANDLE,
        #: invalid parameter
        DCAMERR_INVALIDPARAM,
        #: invalid property value
        DCAMERR_INVALIDVALUE,
        #: value is out of range
        DCAMERR_OUTOFRANGE,
        #: the property is not writable
        DCAMERR_NOTWRITABLE,
        #: the property is not readable
        DCAMERR_NOTREADABLE,
        #: the property id is invalid
        DCAMERR_INVALIDPROPERTYID,
        #: old API cannot present the value because only new API need to be used
        DCAMERR_NEWAPIREQUIRED,
        #: this error happens DCAM get error code from camera unexpectedly
        DCAMERR_WRONGHANDSHAKE,
        #: there is no altenative or influence id, or no more property id
        DCAMERR_NOPROPERTY,
        #: the property id specifies channel but channel is invalid
        DCAMERR_INVALIDCHANNEL,
        #: the property id specifies channel but channel is invalid
        DCAMERR_INVALIDVIEW,
        #: the combination of subarray values are invalid
        DCAMERR_INVALIDSUBARRAY,
        #: the property cannot access during this DCAM STATUS
        DCAMERR_ACCESSDENY,
        #: the property does not have value text
        DCAMERR_NOVALUETEXT,
        #: at least one property value is wrong
        DCAMERR_WRONGPROPERTYVALUE,
        #: the paired camera does not have same parameter
        DCAMERR_DISHARMONY,
        #: framebundle mode should be OFF under current property settings
        DCAMERR_FRAMEBUNDLESHOULDBEOFF,
        #: the frame index is invalid
        DCAMERR_INVALIDFRAMEINDEX,
        #: the session index is invalid
        DCAMERR_INVALIDSESSIONINDEX,
        #: not take the dark and shading correction data yet
        DCAMERR_NOCORRECTIONDATA,
        #: each channel has own property value so can't return overall property value
        DCAMERR_CHANNELDEPENDENTVALUE,
        #: each view has own property value so can't return overall property value
        DCAMERR_VIEWDEPENDENTVALUE,
        #: the setting of properties are invalid on sampling calibration data
        DCAMERR_INVALIDCALIBSETTING,
        #: system memory size is too small
        DCAMERR_LESSSYSTEMMEMORY,
        #: camera does not support the function or property with current settings
        DCAMERR_NOTSUPPORT,

        ##
        ## camera or bus trouble
        ##
        #: failed to read data from camera
        DCAMERR_FAILREADCAMERA,
        #: failed to write data to the camera
        DCAMERR_FAILWRITECAMERA,
        #: conflict the com port name user set
        DCAMERR_CONFLICTCOMMPORT,
        #: optics part is unplugged so please check it
        DCAMERR_OPTICS_UNPLUGGED,
        #: fail calibration
        DCAMERR_FAILCALIBRATION,

        ## 0x84000100 - 0x840001FF, DCAMERR_INVALIDMEMBER_x ##
        DCAMERR_INVALIDMEMBER_3,##		3th member variable is invalid value	##
        DCAMERR_INVALIDMEMBER_5,##		5th member variable is invalid value	##
        DCAMERR_INVALIDMEMBER_7,##		7th member variable is invalid value	##
        DCAMERR_INVALIDMEMBER_8,##		7th member variable is invalid value	##
        DCAMERR_INVALIDMEMBER_9,##		9th member variable is invalid value	##
        DCAMERR_FAILEDOPENRECFILE,##		DCAMREC failed to open the file	##
        DCAMERR_INVALIDRECHANDLE,##		DCAMREC is invalid handle	##
        DCAMERR_FAILEDWRITEDATA,##		DCAMREC failed to write the data	##
        DCAMERR_FAILEDREADDATA,##		DCAMREC failed to read the data	##
        DCAMERR_NOWRECORDING,##		DCAMREC is recording data now	##
        DCAMERR_WRITEFULL,##		DCAMREC writes full frame of the session	##
        DCAMERR_ALREADYOCCUPIED,##		DCAMREC handle is already occupied by other HDCAM	##
        DCAMERR_TOOLARGEUSERDATASIZE,##		DCAMREC is set the large value to user data size	##
        DCAMERR_NOIMAGE,##		not stored image in buffer on bufrecord ##
        #: DCAMWAIT handle is invalid
        DCAMERR_INVALIDWAITHANDLE,
        #: DCAM module vesion is older than the version that the camera requests
        DCAMERR_NEWRUNTIMEREQUIRED,
        #: camera returns an error on setting version
        DCAMERR_VERSIONMISMATCH,
        #: camera is running in factory mode
        DCAMERR_RUNAS_FACTORYMODE,
        #: unknown image header signature
        DCAMERR_IMAGE_UNKNOWNSIGNATURE,
        #: version of image header is newer than current DCAM can support
        DCAMERR_IMAGE_NEWRUNTIMEREQUIRED,
        #: image header indicates error
        DCAMERR_IMAGE_ERRORSTATUSEXIST,
        #: image header is corrupted
        DCAMERR_IMAGE_HEADERCORRUPTED,
        #: image content is corrupted
        DCAMERR_IMAGE_BROKENCONTENT,

        ##
        ## internal error
        ##
        #: no error, nothing have done
        DCAMERR_NONE,
        #: installation progress
        DCAMERR_INSTALLATIONINPROGRESS,
        #: internal error
        DCAMERR_UNREACH,
        #: calling after process terminated
        DCAMERR_UNLOADED,

        DCAMERR_THRUADAPTER,
        #: HDCAM lost connection to camera
        DCAMERR_NOCONNECTION,

        #: not implement
        DCAMERR_NOTIMPLEMENT,

        #: DCAMAPI_INIT::initoptionbytes is invalid
        DCAMERR_APIINIT_INITOPTIONBYTES,
        #: DCAMAPI_INIT::initoption is invalid
        DCAMERR_APIINIT_INITOPTION,

        DCAMERR_INITOPTION_COLLISION_BASE,
        DCAMERR_INITOPTION_COLLISION_MAX,

        ## Between DCAMERR_INITOPTION_COLLISION_BASE and DCAMERR_INITOPTION_COLLISION_MAX means there is collision with initoption in DCAMAPI_INIT. ##
        ## The value "(error code) - DCAMERR_INITOPTION_COLLISION_BASE" indicates the index which second INITOPTION group happens. ##

        ##
        ## success
        ##
        #: no error, general success code, app should check the value is positive
        DCAMERR_SUCCESS


    enum DCAMBUF_FRAME_OPTION:
        DCAMBUF_FRAME_OPTION__VIEW_ALL,
        DCAMBUF_FRAME_OPTION__VIEW_1,
        DCAMBUF_FRAME_OPTION__VIEW_2,
        DCAMBUF_FRAME_OPTION__VIEW_3,
        DCAMBUF_FRAME_OPTION__VIEW_4,

        DCAMBUF_FRAME_OPTION__PROC_HIGHCONTRAST,

        DCAMBUF_FRAME_OPTION__VIEW__STEP,
        DCAMBUF_FRAME_OPTION__VIEW__MASK,
        DCAMBUF_FRAME_OPTION__PROC__MASK

    enum DCAM_PIXELTYPE:
        DCAM_PIXELTYPE_MONO8,
        DCAM_PIXELTYPE_MONO16,
        DCAM_PIXELTYPE_MONO12,
        DCAM_PIXELTYPE_MONO12P,

        DCAM_PIXELTYPE_RGB24,
        DCAM_PIXELTYPE_RGB48,
        DCAM_PIXELTYPE_BGR24,
        DCAM_PIXELTYPE_BGR48,

        DCAM_PIXELTYPE_NONE


    enum DCAMBUF_ATTACHKIND:
        #: copy timestamp to pointer array of user buffer
        DCAMBUF_ATTACHKIND_TIMESTAMP,
        #: copy framestamp to pointer array of user buffer
        DCAMBUF_ATTACHKIND_FRAMESTAMP,

        #: copy timestamp to user buffer
        DCAMBUF_ATTACHKIND_PRIMARY_TIMESTAMP,
        #: copy framestamp to user buffer
        DCAMBUF_ATTACHKIND_PRIMARY_FRAMESTAMP,

        #: copy image to user buffer
        DCAMBUF_ATTACHKIND_FRAME


    enum DCAMCAP_TRANSFERKIND:
        DCAMCAP_TRANSFERKIND_FRAME

    ### STATUS ###
    enum DCAMCAP_STATUS:
        DCAMCAP_STATUS_ERROR,
        #: now capturing
        DCAMCAP_STATUS_BUSY,
        #: not capturing, but ready to start capturing
        DCAMCAP_STATUS_READY,
        #: device is not prepared for immediate capturing
        DCAMCAP_STATUS_STABLE,
        #: device is not fit for capture
        DCAMCAP_STATUS_UNSTABLE

    enum DCAMWAIT_EVENT:
        DCAMWAIT_CAPEVENT_TRANSFERRED,
        DCAMWAIT_CAPEVENT_FRAMEREADY,
        DCAMWAIT_CAPEVENT_CYCLEEND,
        DCAMWAIT_CAPEVENT_EXPOSUREEND,
        DCAMWAIT_CAPEVENT_STOPPED

    ### START ###
    enum DCAMCAP_START:
        DCAMCAP_START_SEQUENCE,
        DCAMCAP_START_SNAP

    ### STRING ID ###
    enum DCAM_IDSTR:
        #: bus information
        DCAM_IDSTR_BUS,
        #: camera ID (serial number or bus specific string)
        DCAM_IDSTR_CAMERAID,
        #: always "Hamamatsu"
        DCAM_IDSTR_VENDOR,
        #: camera model name
        DCAM_IDSTR_MODEL,
        #: version of the firmware or hardware
        DCAM_IDSTR_CAMERAVERSION,
        #: version of the low level driver which DCAM is using
        DCAM_IDSTR_DRIVERVERSION,
        #: version of the DCAM module
        DCAM_IDSTR_MODULEVERSION,
        #: version of DCAM-API specification
        DCAM_IDSTR_DCAMAPIVERSION,

        #: camera series name (nickname)
        DCAM_IDSTR_CAMERA_SERIESNAME,

        #: optical block model name
        DCAM_IDSTR_OPTICALBLOCK_MODEL,
        #: optical block serial number
        DCAM_IDSTR_OPTICALBLOCK_ID,
        #: description of optical block
        DCAM_IDSTR_OPTICALBLOCK_DESCRIPTION,
        #: description of optical block channel 1
        DCAM_IDSTR_OPTICALBLOCK_CHANNEL_1,
        #: description of optical block channel 2
        DCAM_IDSTR_OPTICALBLOCK_CHANNEL_2


    ### WAIT TIMEOUT ###
    ### INITIALIZE PARAMETER ###
    ### METADATA KIND ###
    enum DCAMBUF_METADATAKIND:
        #: captured timing
        DCAMBUF_METADATAKIND_TIMESTAMPS,
        #: frame index
        DCAMBUF_METADATAKIND_FRAMESTAMPS

    ### DCAM DATA {OPTION / (KIND) / (ATTRIBUTE) / (REGION TYPE) / (LUT TYPE)} ###
    enum DCAMDATA_KIND:
        DCAMDATA_KIND__REGION,
        DCAMDATA_KIND__LUT,
        DCAMDATA_KIND__NONE

    enum DCAMDATA_ATTRIBUTE:
        DCAMDATA_ATTRIBUTE__ACCESSREADY,
        DCAMDATA_ATTRIBUTE__ACCESSBUSY,

        DCAMDATA_ATTRIBUTE__HASVIEW,

        DCAMDATA_ATTRIBUTE__MASK

    enum DCAMDATA_REGIONTYPE:
        DCAMDATA_REGIONTYPE__BYTEMASK,
        DCAMDATA_REGIONTYPE__RECT16ARRAY,

        DCAMDATA_REGIONTYPE__ACCESSREADY,
        DCAMDATA_REGIONTYPE__ACCESSBUSY,
        DCAMDATA_REGIONTYPE__HASVIEW,

        DCAMDATA_REGIONTYPE__BODYMASK,
        DCAMDATA_REGIONTYPE__ATTRIBUTEMASK,

        DCAMDATA_REGIONTYPE__NONE

    enum DCAMDATA_LUTTYPE:
        DCAMDATA_LUTTYPE__SEGMENTED_LINEAR,
        DCAMDATA_LUTTYPE__MONO16,

        DCAMDATA_LUTTYPE__ACCESSREADY,
        DCAMDATA_LUTTYPE__ACCESSBUSY,

        DCAMDATA_LUTTYPE__BODYMASK,
        DCAMDATA_LUTTYPE__ATTRIBUTEMASK,

        DCAMDATA_LUTTYPE__NONE

    ### BUFFER PROC TYPE ###
    enum DCAMBUF_PROCTYPE:
        DCAMBUF_PROCTYPE__HIGHCONTRASTMODE,
        DCAMBUF_PROCTYPE__NONE

    ### CODE PAGE ###
    ### CAPABILITY ###
    enum DCAMDEV_CAPDOMAIN:
        DCAMDEV_CAPDOMAIN__DCAMDATA,
        DCAMDEV_CAPDOMAIN__FRAMEOPTION,
        DCAMDEV_CAPDOMAIN__FUNCTION

    enum DCAMDEV_CAPFLAG:
        DCAMDEV_CAPFLAG_FRAMESTAMP,
        DCAMDEV_CAPFLAG_TIMESTAMP,
        DCAMDEV_CAPFLAG_CAMERASTAMP,
        DCAMDEV_CAPFLAG_NONE

    enum DCAMREC_STATUSFLAG:
        DCAMREC_STATUSFLAG_NONE,
        DCAMREC_STATUSFLAG_RECORDING

    ##
    ## constant declaration
    ##

    ##
    ## structures
    ##
    ctypedef void* HDCAMWAIT

    struct DCAM_GUID:
        pass

    ctypedef struct DCAMAPI_INIT:
        int32				size				    # [in]
        int32				iDeviceCount		    # [out]
        int32				reserved			    # reserved
        int32				initoptionbytes		    # [in] maximum bytes of initoption array.
        const int32*		initoption			    # [in ptr] initialize options. Choose from DCAMAPI_INITOPTION
        const DCAM_GUID*	guid				    # [in ptr]

    ctypedef struct DCAMDEV_OPEN:
        int32				size					# [in]
        int32				index					# [in]
        HDCAM				hdcam					# [out]

    ctypedef struct DCAMDEV_CAPABILITY:
        int32				size					# [in]
        int32				domain					# [in] DCAMDEV_CAPDOMAIN__*
        int32				capflag				    # [out] available flags in current condition.
        int32				kind					# [in] data kind in domain

    ctypedef struct DCAMDEV_CAPABILITY_LUT:
        DCAMDEV_CAPABILITY	hdr					    # [in] size:		size of this structure
                                                    # [in] domain:		DCAMDEV_CAPDOMAIN__DCAMDATA
                                                    # [out] capflag:	DCAMDATA_LUTTYPE__*
                                                    # [in] kind:		DCAMDATA_KIND__LUT
        int32				linearpointmax			# [out] max of linear lut point

    ctypedef struct DCAMDEV_CAPABILITY_REGION:
        DCAMDEV_CAPABILITY	hdr					    # [in] size:		size of this structure
                                                    # [in] domain:		DCAMDEV_CAPDOMAIN__DCAMDATA
                                                    # [out] capflag:	DCAMDATA_REGIONTYPE__*
                                                    # [in] kind:		DCAMDATA_KIND__REGION
        int32				horzunit				# [out] horizontal step
        int32				vertunit				# [out] vertical step

    ctypedef struct DCAMDEV_CAPABILITY_FRAMEOPTION:
        DCAMDEV_CAPABILITY	hdr					    # [in] size:		size of this structure
                                                    # [in] domain:		DCAMDEV_CAPDOMAIN__FRAMEOPTION
                                                    # [out] capflag:	available DCAMBUF_PROCTYPE__* flags in current condition.
                                                    # [in] kind:		0 reserved
        int32	supportproc						    # [out] support DCAMBUF_PROCTYPE__* flags in the camera. hdr.capflag may be 0 if the function doesn't work in current condition.

    ctypedef struct DCAMDEV_STRING:
        int32				size					# [in]
        int32				iString				    # [in]
        char*				text					# [in,obuf]
        int32				textbytes				# [in]

    ctypedef struct DCAMDATA_HDR:
        int32				size					# [in]	size of whole structure, not only this
        int32				iKind					# [in] DCAMDATA_KIND__*
        int32				option					# [in] DCAMDATA_OPTION__*
        int32				reserved2				# [in] 0 reserved

    struct DCAMDATA_REGION:
        pass

    struct DCAMDATA_REGIONRECT:
        pass

    struct DCAMDATA_LUT:
        pass

    struct DCAMDATA_LINEARLUT:
        pass

    ctypedef struct DCAMPROP_ATTR:
        ## input parameters ##
        int32				cbSize					# [in] size of this structure
        int32				iProp					# DCAMIDPROPERTY
        int32				option					# DCAMPROPOPTION
        int32				iReserved1				# must be 0

        ## output parameters ##
        int32				attribute				# DCAMPROPATTRIBUTE
        int32				iGroup					# 0 reserved
        int32				iUnit					# DCAMPROPUNIT
        int32				attribute2				# DCAMPROPATTRIBUTE2

        double				valuemin				# minimum value
        double				valuemax				# maximum value
        double				valuestep				# minimum stepping between a value and the next
        double				valuedefault			# default value

        int32				nMaxChannel			    # max channel if supports
        int32				iReserved3				# reserved to 0
        int32				nMaxView				# max view if supports

        int32				iProp_NumberOfElement	# property id to get number of elements of this property if it is array
        int32				iProp_ArrayBase		    # base id of array if element
        int32				iPropStep_Element		# step for iProp to next element

    ctypedef struct DCAMPROP_VALUETEXT:
        int32				cbSize					# [in] size of this structure
        int32				iProp					# [in] DCAMIDPROP
        double				value					# [in] value of property
        char*				text					# [in,obuf] text of the value
        int32				textbytes				# [in] text buf size

    ctypedef struct DCAMBUF_ATTACH:
        int32				size					# [in] size of this structure.
        int32				iKind					# [in] DCAMBUF_ATTACHKIND
        void**				buffer					# [in,ptr]
        int32				buffercount			    # [in]

    ctypedef struct DCAM_TIMESTAMP:
        _ui32				sec					    # [out]
        int32				microsec				# [out]

    ctypedef struct DCAMCAP_TRANSFERINFO:
        int32				size					# [in] size of this structure.
        int32				iKind					# [in] DCAMCAP_TRANSFERKIND
        int32				nNewestFrameIndex		# [out]
        int32				nFrameCount			    # [out]

    ctypedef struct DCAMBUF_FRAME:
        # copyframe() and lockframe() use this structure. Some members have different direction.
        # [i:o] means, the member is input at copyframe() and output at lockframe().
        # [i:i] and [o:o] means always input and output at both function.
        # "input" means application has to set the value before calling.
        # "output" means function filles a value at returning.
        int32				size					# [i:i] size of this structure.
        int32				iKind					# reserved. set to 0.
        int32				option					# reserved. set to 0.
        int32				iFrame					# [i:i] frame index
        void*				buf					    # [i:o] pointer for top-left image
        int32				rowbytes				# [i:o] byte size for next line.
        DCAM_PIXELTYPE		type					# reserved. set to 0.
        int32				width					# [i:o] horizontal pixel count
        int32				height					# [i:o] vertical line count
        int32				left					# [i:o] horizontal start pixel
        int32				top					    # [i:o] vertical start line
        DCAM_TIMESTAMP		timestamp				# [o:o] timestamp
        int32				framestamp				# [o:o] framestamp
        int32				camerastamp			    # [o:o] camerastamp

    ctypedef struct DCAMWAIT_OPEN:
        int32				size					# [in] size of this structure.
        int32				supportevent			# [out]
        HDCAMWAIT			hwait					# [out]
        HDCAM				hdcam					# [in]

    ctypedef struct DCAMWAIT_START:
        int32				size					# [in] size of this structure.
        int32				eventhappened			# [out]
        int32				eventmask				# [in]
        int32				timeout				    # [in]

    ctypedef struct DCAM_METADATAHDR:
        int32				size					# [in] size of whole structure, not only this.
        int32				iKind					# [in] DCAMBUF_METADATAKIND
        int32				option					# [in] value meaning depends on DCAMBUF_METADATAKIND
        int32				iFrame					# [in] frfame index
    ##
    ## structures
    ##

    ##
    ## functions
    ##
    ## initialize, uninitialize and misc ##
    DCAMERR dcamapi_init			( DCAMAPI_INIT* param )
    DCAMERR dcamapi_init			()
    DCAMERR dcamapi_uninit			()
    DCAMERR dcamdev_open			( DCAMDEV_OPEN* param )
    DCAMERR dcamdev_close			( HDCAM h )

    ## device data ##
    DCAMERR dcamdev_getcapability	( HDCAM h, DCAMDEV_CAPABILITY* param )
    DCAMERR dcamdev_getstring		( HDCAM h, DCAMDEV_STRING* param )
    DCAMERR dcamdev_setdata			( HDCAM h, DCAMDATA_HDR* param )
    DCAMERR dcamdev_getdata			( HDCAM h, DCAMDATA_HDR* param )

    ## property control ##
    DCAMERR dcamprop_getattr		( HDCAM h, DCAMPROP_ATTR* param )
    DCAMERR dcamprop_getvalue		( HDCAM h, int32 iProp, double* pValue )
    DCAMERR dcamprop_setvalue		( HDCAM h, int32 iProp, double  fValue )
    DCAMERR dcamprop_setgetvalue	( HDCAM h, int32 iProp, double* pValue, int32 option )
    DCAMERR dcamprop_setgetvalue	( HDCAM h, int32 iProp, double* pValue )
    DCAMERR dcamprop_queryvalue		( HDCAM h, int32 iProp, double* pValue, int32 option )
    DCAMERR dcamprop_getnextid		( HDCAM h, int32* pProp, int32 option )
    DCAMERR dcamprop_getnextid		( HDCAM h, int32* pProp )
    DCAMERR dcamprop_getname		( HDCAM h, int32 iProp, char* text, int32 textbytes )
    DCAMERR dcamprop_getvaluetext	( HDCAM h, DCAMPROP_VALUETEXT* param )

    ## buffer control ##
    DCAMERR dcambuf_alloc			( HDCAM h, int32 framecount )	# call dcambuf_release() to free.
    DCAMERR dcambuf_attach			( HDCAM h, const DCAMBUF_ATTACH* param )
    DCAMERR dcambuf_release			( HDCAM h, int32 iKind )
    DCAMERR dcambuf_release			( HDCAM h )
    DCAMERR dcambuf_lockframe		( HDCAM h, DCAMBUF_FRAME* pFrame )
    DCAMERR dcambuf_copyframe		( HDCAM h, DCAMBUF_FRAME* pFrame )
    DCAMERR dcambuf_copymetadata	( HDCAM h, DCAM_METADATAHDR* hdr )

    ## capturing ##
    DCAMERR dcamcap_start			( HDCAM h, int32 mode )
    DCAMERR dcamcap_stop			( HDCAM h )
    DCAMERR dcamcap_status			( HDCAM h, int32* pStatus )
    DCAMERR dcamcap_transferinfo	( HDCAM h, DCAMCAP_TRANSFERINFO* param )
    DCAMERR dcamcap_firetrigger		( HDCAM h, int32 iKind )
    DCAMERR dcamcap_firetrigger		( HDCAM h )

    ## wait abort handle control ##
    DCAMERR dcamwait_open			( DCAMWAIT_OPEN* param )
    DCAMERR dcamwait_close			( HDCAMWAIT hWait )
    DCAMERR dcamwait_start			( HDCAMWAIT hWait, DCAMWAIT_START* param )
    DCAMERR dcamwait_abort			( HDCAMWAIT hWait )

    ## utilities ##
    int failed( DCAMERR err )
    ##
    ## functions
    ##
