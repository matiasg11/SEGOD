export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      equipment: {
        Row: {
          acquired_at: string | null
          brand: string | null
          category: string | null
          certificate_url: string | null
          code: string | null
          controlled_magnitude: string | null
          expires_at: string | null
          frequency: string | null
          id: string
          last_calibrated_at: string | null
          last_verified_at: string | null
          location: string | null
          main_use: string | null
          model: string | null
          name: string
          notes: string | null
          requires_calibration: boolean | null
          requires_verification: boolean | null
          responsible_name: string | null
          source_row: Json
          status: string | null
        }
        Insert: {
          acquired_at?: string | null
          brand?: string | null
          category?: string | null
          certificate_url?: string | null
          code?: string | null
          controlled_magnitude?: string | null
          expires_at?: string | null
          frequency?: string | null
          id?: string
          last_calibrated_at?: string | null
          last_verified_at?: string | null
          location?: string | null
          main_use?: string | null
          model?: string | null
          name: string
          notes?: string | null
          requires_calibration?: boolean | null
          requires_verification?: boolean | null
          responsible_name?: string | null
          source_row?: Json
          status?: string | null
        }
        Update: {
          acquired_at?: string | null
          brand?: string | null
          category?: string | null
          certificate_url?: string | null
          code?: string | null
          controlled_magnitude?: string | null
          expires_at?: string | null
          frequency?: string | null
          id?: string
          last_calibrated_at?: string | null
          last_verified_at?: string | null
          location?: string | null
          main_use?: string | null
          model?: string | null
          name?: string
          notes?: string | null
          requires_calibration?: boolean | null
          requires_verification?: boolean | null
          responsible_name?: string | null
          source_row?: Json
          status?: string | null
        }
        Relationships: []
      }
      raw_test_data: {
        Row: {
          amended_at: string | null
          captured_at: string
          captured_by: string | null
          data_type: string
          id: string
          raw_values: Json
          sample_id: string
          sample_test_id: string
          sequence_no: number
          source_row_number: number | null
          source_sheet: string | null
          subtest_id: string | null
        }
        Insert: {
          amended_at?: string | null
          captured_at?: string
          captured_by?: string | null
          data_type: string
          id?: string
          raw_values: Json
          sample_id: string
          sample_test_id: string
          sequence_no?: number
          source_row_number?: number | null
          source_sheet?: string | null
          subtest_id?: string | null
        }
        Update: {
          amended_at?: string | null
          captured_at?: string
          captured_by?: string | null
          data_type?: string
          id?: string
          raw_values?: Json
          sample_id?: string
          sample_test_id?: string
          sequence_no?: number
          source_row_number?: number | null
          source_sheet?: string | null
          subtest_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "raw_test_data_sample_id_fkey"
            columns: ["sample_id"]
            isOneToOne: false
            referencedRelation: "samples"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "raw_test_data_sample_test_id_fkey"
            columns: ["sample_test_id"]
            isOneToOne: false
            referencedRelation: "sample_tests"
            referencedColumns: ["id"]
          },
        ]
      }
      sample_tests: {
        Row: {
          applied_standard: string | null
          classification: string | null
          compliance: string | null
          created_at: string
          created_by: string | null
          equipment_used: string | null
          final_result: string | null
          id: string
          locked: boolean
          notes: string | null
          performed_by: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          sample_id: string
          status: string
          test_catalog_id: string | null
          test_name: string
          tested_at: string | null
          units: string | null
          updated_at: string
        }
        Insert: {
          applied_standard?: string | null
          classification?: string | null
          compliance?: string | null
          created_at?: string
          created_by?: string | null
          equipment_used?: string | null
          final_result?: string | null
          id?: string
          locked?: boolean
          notes?: string | null
          performed_by?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          sample_id: string
          status?: string
          test_catalog_id?: string | null
          test_name: string
          tested_at?: string | null
          units?: string | null
          updated_at?: string
        }
        Update: {
          applied_standard?: string | null
          classification?: string | null
          compliance?: string | null
          created_at?: string
          created_by?: string | null
          equipment_used?: string | null
          final_result?: string | null
          id?: string
          locked?: boolean
          notes?: string | null
          performed_by?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          sample_id?: string
          status?: string
          test_catalog_id?: string | null
          test_name?: string
          tested_at?: string | null
          units?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "sample_tests_performed_by_fkey"
            columns: ["performed_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sample_tests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sample_tests_sample_id_fkey"
            columns: ["sample_id"]
            isOneToOne: false
            referencedRelation: "samples"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sample_tests_test_catalog_id_fkey"
            columns: ["test_catalog_id"]
            isOneToOne: false
            referencedRelation: "test_catalog"
            referencedColumns: ["id"]
          },
        ]
      }
      samples: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          location_and_storage: string | null
          lot_batch_work_order: string | null
          model_size_hand: string | null
          notes: string | null
          product: string
          quantity_received: number | null
          received_at: string
          requested_standard: string | null
          requested_tests: string | null
          requester: string | null
          sample_name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          location_and_storage?: string | null
          lot_batch_work_order?: string | null
          model_size_hand?: string | null
          notes?: string | null
          product: string
          quantity_received?: number | null
          received_at?: string
          requested_standard?: string | null
          requested_tests?: string | null
          requester?: string | null
          sample_name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          location_and_storage?: string | null
          lot_batch_work_order?: string | null
          model_size_hand?: string | null
          notes?: string | null
          product?: string
          quantity_received?: number | null
          received_at?: string
          requested_standard?: string | null
          requested_tests?: string | null
          requester?: string | null
          sample_name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      staff: {
        Row: {
          area: string | null
          authorized_tests: string | null
          can_approve_reports: boolean
          can_manage_records: boolean
          can_run_tests: boolean
          competence_evidence: string | null
          created_at: string
          full_name: string
          id: string
          impartiality_declared: boolean | null
          job_title: string | null
          legacy_id: string | null
          notes: string | null
          status: string
          updated_at: string
        }
        Insert: {
          area?: string | null
          authorized_tests?: string | null
          can_approve_reports?: boolean
          can_manage_records?: boolean
          can_run_tests?: boolean
          competence_evidence?: string | null
          created_at?: string
          full_name: string
          id?: string
          impartiality_declared?: boolean | null
          job_title?: string | null
          legacy_id?: string | null
          notes?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          area?: string | null
          authorized_tests?: string | null
          can_approve_reports?: boolean
          can_manage_records?: boolean
          can_run_tests?: boolean
          competence_evidence?: string | null
          created_at?: string
          full_name?: string
          id?: string
          impartiality_declared?: boolean | null
          job_title?: string | null
          legacy_id?: string | null
          notes?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      test_catalog: {
        Row: {
          active: boolean
          available_in_house: boolean
          id: string
          method: string | null
          name: string
          raw_schema_key: string | null
          required_equipment: string | null
          standard: string | null
        }
        Insert: {
          active?: boolean
          available_in_house?: boolean
          id?: string
          method?: string | null
          name: string
          raw_schema_key?: string | null
          required_equipment?: string | null
          standard?: string | null
        }
        Update: {
          active?: boolean
          available_in_house?: boolean
          id?: string
          method?: string | null
          name?: string
          raw_schema_key?: string | null
          required_equipment?: string | null
          standard?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const

