/**
 * Copyright (C) 2009 Michael 'Mickey' Lauer <mlauer@vanille-media.de>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 */

[CCode (cheader_filename = "conversions.h,util.h", cprefix = "", lower_case_cprefix = "")]
namespace Conversions {

    string ucs2_to_utf8( string data );
    string sim_string_to_utf8( string buffer, int length );

    void decode_hex_own_buf( string inbuffer,
                             long length,
                             out long items_written,
                             char terminator,
                             [CCode (array_length = false)] char[] outbuffer );
}

[CCode (cheader_filename = "conversions.h,util.h,smsutil.h", cprefix = "", lower_case_cprefix = "")]
namespace Sms
{
    public const int CBS_MAX_GSM_CHARS;

    [CCode (cprefix = "SMS_TYPE_")]
    public enum Type
    {
        DELIVER,
        DELIVER_REPORT_ACK,
        DELIVER_REPORT_ERROR,
        STATUS_REPORT,
        SUBMIT,
        SUBMIT_REPORT_ACK,
        SUBMIT_REPORT_ERROR,
        COMMAND
    }

    /* 23.040 Section 9.1.2.5 */
    [CCode (cprefix = "SMS_NUMBER_TYPE_")]
    public enum NumberType
    {
        UNKNOWN,
        INTERNATIONAL,
        NATIONAL,
        NETWORK_SPECIFIC,
        SUBSCRIBER,
        ALPHANUMERIC,
        ABBREVIATED,
        RESERVED
    }

    /* 23.040 Section 9.1.2.5 */
    [CCode (cprefix = "SMS_NUMBERING_PLAN_")]
    public enum NumberingPlan
    {
        UNKNOWN,
        ISDN,
        DATA,
        TELEX,
        SC1,
        SC2,
        NATIONAL,
        PRIVATE,
        ERMES,
        RESERVED
    }

    [CCode (cprefix = "SMS_VALIDITY_PERIOD_FORMAT_")]
    public enum ValidityPeriodFormat
    {
        ABSENT,
        ENHANCED,
        RELATIVE,
        ABSOLUTE,
    }

    [CCode (cprefix = "SMS_ST_")]
    public enum Status
    {
        COMPLETED_RECEIVED,
        COMPLETED_UNABLE_TO_CONFIRM,
        COMPLETED_REPLACED,
        COMPLETED_LAST,
        TEMPORARY_CONGESTION,
        TEMPORARY_SME_BUSY,
        TEMPORARY_NO_RESPONSE,
        TEMPORARY_SERVICE_REJECTED,
        TEMPORARY_QOS_UNAVAILABLE,
        TEMPORARY_SME_ERROR,
        TEMPORARY_LAST,
        PERMANENT_RP_ERROR,
        PERMANENT_INVALID_DESTINATION,
        PERMANENT_CONNECTION_REJECTED,
        PERMANENT_NOT_OBTAINABLE,
        PERMANENT_QOS_UNAVAILABLE,
        PERMANENT_INTERWORKING_UNAVAILABLE,
        PERMANENT_VALIDITY_PERIOD_EXPIRED,
        PERMANENT_DELETED,
        PERMANENT_SC_ADMIN_DELETED,
        PERMANENT_SM_DOES_NOT_EXIST,
        PERMANENT_LAST,
        TEMPFINAL_CONGESTION,
        TEMPFINAL_SME_BUSY,
        TEMPFINAL_NO_RESPONSE,
        TEMPFINAL_SERVICE_REJECTED,
        TEMPFINAL_QOS_UNAVAILABLE,
        TEMPFINAL_SME_ERROR,
        TEMPFINAL_LAST
    }

    [CCode (cprefix = "SMS_CT_")]
    public enum Ct
    {
        ENQUIRY,
        CANCEL_SRR,
        DELETE_SM,
        ENABLE_SRR
    }

    [CCode (cprefix = "SMS_IEI_")]
    public enum Iei
    {
        CONCATENATED_8BIT,
        SPECIAL_MESSAGE_INDICATION,
        APPLICATION_ADDRESS_8BIT,
        APPLICATION_ADDRESS_16BIT,
        SMSC_CONTROL_PARAMETERS,
        UDH_SOURCE_INDICATOR,
        CONCATENATED_16BIT,
        WCMP,
        TEXT_FORMAT,
        PREDEFINED_SOUND,
        USER_DEFINED_SOUND,
        PREDEFINED_ANIMATION,
        LARGE_ANIMATION,
        SMALL_ANIMATION,
        LARGE_PICTURE,
        SMALL_PICTURE,
        VARIABLE_PICTURE,
        USER_PROMPT_INDICATOR,
        EXTENDED_OBJECT,
        REUSED_EXTENDED_OBJECT,
        COMPRESSION_CONTROL,
        OBJECT_DISTRIBUTION_INDICATOR,
        STANDARD_WVG_OBJECT,
        CHARACTER_SIZE_WVG_OBJECT,
        EXTENDED_OBJECT_DATA_REQUEST_COMMAND,
        RFC822_EMAIL_HEADER,
        HYPERLINK_ELEMENT,
        REPLY_ADDRESS_ELEMENT,
        ENHANCED_VOICE_MAIL_INFORMATION,
        NATIONAL_LANGUAGE_SINGLE_SHIFT,
        NATIONAL_LANGUAGE_LOCKING_SHIFT,
        INVALID
    }

    [CCode (cprefix = "SMS_")]
    public enum Class
    {
        CLASS_0,
        CLASS_1,
        CLASS_2,
        CLASS_3,
        CLASS_UNSPECIFIED,
    }

    [CCode (cprefix = "SMS_")]
    public enum Charset
    {
        CHARSET_7BIT,
        CHARSET_8BIT,
        CHARSET_UCS2
    }

    [CCode (cprefix = "SMS_MWI_TYPE_")]
    public enum MwiType
    {
        VOICE,
        FAX,
        EMAIL,
        OTHER,
        VIDEO,
    }

    [CCode (cprefix = "SMS_PID_TYPE_")]
    public enum PidType
    {
        SM_TYPE_0,
        REPLACE_SM_TYPE_1,
        REPLACE_SM_TYPE_2,
        REPLACE_SM_TYPE_3,
        REPLACE_SM_TYPE_4,
        REPLACE_SM_TYPE_5,
        REPLACE_SM_TYPE_6,
        REPLACE_SM_TYPE_7,
        ENHANCED_MESSAGE_SERVICE,
        RETURN_CALL,
        ANSI136,
        ME_DOWNLOAD,
        ME_DEPERSONALIZATION,
        USIM_DOWNLOAD,
    }

    [CCode (cname = "struct sms_address", cprefix = "sms_address_", destroy_function = "")]
    public struct Address
    {
        public unowned string to_string();
        public void from_string( string str );

        public Sms.NumberType number_type;
        public Sms.NumberingPlan numbering_plan;
        public char[] address; /* Max 20 in semi-octet, 11 in alnum */
    }

    [CCode (cname = "struct sms_scts", destroy_function = "")]
    public struct Scts
    {
        public uint8 year;
        public uint8 month;
        public uint8 day;
        public uint8 hour;
        public uint8 minute;
        public uint8 second;
        public int8 timezone;
    }

    [CCode (cname = "struct sms_validity_period", destroy_function = "")]
    public struct ValidityPeriod
    {
        public uint8 relative;
        public Sms.Scts absolute;
        public uint8 enhanced;
    }

    [CCode (cname = "struct sms_deliver", destroy_function = "")]
    public struct Deliver
    {
        public bool mms;
        public bool sri;
        public bool udhi;
        public bool rp;
        public Sms.Address oaddr;
        public uint8 pid;
        public uint8 dcs;
        public Sms.Scts scts;
        public uint8 udl;
        public uint8 ud[];
    }

    [CCode (cname = "struct sms_deliver_err_report", destroy_function = "")]
    public struct DeliverErrorReport
    {
        public bool udhi;
        public uint8 fcs;
        public uint8 pi;
        public uint8 pid;
        public uint8 dcs;
        public uint8 udl;
        public uint8 ud[];
    }

    [CCode (cname = "struct sms_deliver_ack_report", destroy_function = "")]
    public struct DeliverAckReport
    {
        public bool udhi;
        public uint8 pi;
        public uint8 pid;
        public uint8 dcs;
        public uint8 udl;
        public uint8 ud[];
    }

    [CCode (cname = "struct sms_command", destroy_function = "")]
    public struct Command
    {
        public bool udhi;
        public bool srr;
        public uint8 mr;
        public uint8 pid;
        public Sms.Ct ct;
        public uint8 mn;
        public Sms.Address daddr;
        public uint8 cdl;
        public uint8 cd[];
    }

    [CCode (cname = "struct sms_status_report", destroy_function = "")]
    public struct StatusReport
    {
        public bool udhi;
        public bool mms;
        public bool srq;
        public uint8 mr;
        public Sms.Address raddr;
        public Sms.Scts scts;
        public Sms.Scts dt;
        public Sms.Status st;
        public uint8 pi;
        public uint8 pid;
        public uint8 dcs;
        public uint8 udl;
        public uint8 ud[];
    }

    [CCode (cname = "struct sms_submit", destroy_function = "")]
    public struct Submit
    {
        public bool rd;
        public Sms.ValidityPeriodFormat vpf;
        public bool rp;
        public bool udhi;
        public bool srr;
        public uint8 mr;
        public Sms.Address daddr;
        public uint8 pid;
        public uint8 dcs;
        public Sms.ValidityPeriod vp;
        public uint8 udl;
        public uint8 ud[];
    }

    [CCode (cname = "struct sms_submit_ack_report", destroy_function = "")]
    public struct SubmitAckReport
    {
        public bool udhi;
        public uint8 pi;
        public Sms.Scts scts;
        public uint8 pid;
        public uint8 dcs;
        public uint8 udl;
        public uint8 ud[];
    }

    [CCode (cname = "struct sms_submit_err_report", destroy_function = "")]
    public struct SubmitErrorReport
    {
        public bool udhi;
        public uint8 fcs;
        public uint8 pi;
        public Sms.Scts scts;
        public uint8 pid;
        public uint8 dcs;
        public uint8 udl;
        public uint8 ud[];
    }

    [CCode (cname = "struct sms", destroy_function = "")]
    public struct Message
    {
        public string to_string()
        {
            var list = new GLib.SList<Sms.Message*>();
            list.append( &this );
            return Sms.decode_text( list );
        }


        public string number()
        {
            switch ( type )
            {
                case Sms.Type.DELIVER:
                    return deliver.oaddr.to_string();
                case Sms.Type.STATUS_REPORT:
                    return status_report.raddr.to_string();
                case Sms.Type.SUBMIT:
                    return submit.daddr.to_string();
                case Sms.Type.COMMAND:
                    return command.daddr.to_string();
                default:
                    return "unknown";
            }
        }

        public Sms.Address sc_addr;
        public Sms.Type type;
        /* <union> */
        public Sms.Deliver deliver;
        public Sms.DeliverAckReport deliver_ack_report;
        public Sms.DeliverErrorReport deliver_err_report;
        public Sms.Submit submit;
        public Sms.SubmitAckReport submit_ack_report;
        public Sms.SubmitErrorReport submit_err_report;
        public Sms.Command command;
        public Sms.StatusReport status_report;
        /* </union> */
    }

    [CCode (cname = "struct sms_udh_iter", destroy_function = "")]
    public struct UserDataHeaderIter
    {
        public uint8 *data;
        public uint8 offset;
    }

    [CCode (cname = "struct sms_assembly_node", destroy_function = "")]
    public struct AssemblyNode
    {
        public Sms.Address addr;
        public time_t ts;
        //public GLib.SList *fragment_list;
        //public uint8 ref;
        public uint8 max_fragments;
        public uint8 num_fragments;
        public uint bitmap[];
    }

    [CCode (cname = "struct sms_assembly", destroy_function = "sms_assembly_free")]
    public struct Assembly
    {
        string imsi;
        GLib.SList<AssemblyNode?> assembly_list;
    }

    [CCode (cname = "sms_decode")]
    public bool decode( char[] pdu, bool outgoing, int tpdu_len, out Sms.Message message );

    [CCode (cname = "sms_encode")]
    public bool encode( Sms.Message message,
                        out int len,
                        out int tpdu_len,
                        [CCode (array_length = false)] char[] pdu );

    [CCode (cname = "sms_decode_text")]
    public string decode_text( GLib.SList<Sms.Message*> sms_list );
}

namespace Cb
{
    [CCode (cprefix = "CBS_LANGUAGE_")]
    public enum Language
    {
        GERMAN,
        ENGLISH,
        ITALIAN,
        FRENCH,
        SPANISH,
        DUTCH,
        SWEDISH,
        DANISH,
        PORTUGESE,
        FINNISH,
        NORWEGIAN,
        GREEK,
        TURKISH,
        HUNGARIAN,
        POLISH,
        UNSPECIFIED,
        CZECH,
        HEBREW,
        ARABIC,
        RUSSIAN,
        ICELANDIC
    }

    [CCode (cprefix = "CBS_GEO_SCOPE_")]
    public enum GeoScope
    {
        CELL_IMMEDIATE,
        PLMN,
        SERVICE_AREA,
        CELL_NORMAL
    }

    [CCode (cname = "cbs", destroy_function = "")]
    public struct Message
    {
        public GeoScope gs;
        public uint16 message_code;
        public uint8 update_number;
        public uint16 message_identifier;
        public uint8 dcs;
        public uint8 max_pages;
        public uint8 page;
        public uint8 ud[];
    }

    [CCode (cname = "cbs_assembly_node", destroy_function = "")]
    public struct AssemblyNode
    {
        uint32 serial;
        uint16 bitmap;
        GLib.SList<void*> pages;
    }

    [CCode (cname = "cbs_assembly", destroy_function = "cbs_assembly_free")]
    public struct Assembly
    {
        GLib.SList<void*> assembly_list;
        GLib.SList<void*> recv_plmn;
        GLib.SList<void*> recv_loc;
        GLib.SList<void*> recv_cell;
    }

    [CCode (cname = "cbs_topic_range", destroy_function = "")]
    public struct TopicRange
    {
        ushort min;
        ushort max;
    }

    /*
    static inline bool is_bit_set(unsigned char oct, int bit)
    {
        int mask = 0x1 << bit;
        return oct & mask ? TRUE : FALSE;
    }

    static inline unsigned char bit_field(unsigned char oct, int start, int num)
    {
        unsigned char mask = (0x1 << num) - 1;

        return (oct >> start) & mask;
    }
    */
}
